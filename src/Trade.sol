// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ERC1155.sol";
import "./interface/IBodhi.sol";

/**
 * @title Trade
 * @dev A contract for trading ERC1155 assets on the Bodhi platform.
 */
contract Trade is ERC1155TokenReceiver {
    event Buy(
        uint256 indexed appId,
        uint256 indexed assetId, 
        address indexed sender, 
        uint256 tokenAmount, 
        uint256 ethAmount, 
        uint256 fee
    );
    
    event Sell(
        uint256 indexed appId,
        uint256 indexed assetId, 
        address indexed sender, 
        uint256 tokenAmount, 
        uint256 ethAmount, 
        uint256 fee
    );

    IBodhi public bodhi;

    uint256 public idIndex;

    uint256 public constant DEFAULT_APP_FEE = 0.02 ether; // 2%
    uint256 public constant CREATOR_FEE_PERCENT = 0.05 ether; // 5%

    // application id => application address
    mapping(uint256 => address) public applications;

    // application id => application fee
    mapping(uint256 => uint256) public appFee;

    // application id => application revenue
    mapping(uint256 => uint256) public appRevenue;

    /**
     * @dev Constructor function
     * @param _bodhi The address of the Bodhi contract.
     */
    constructor(address _bodhi) {
        bodhi = IBodhi(_bodhi);
    }

    /**
     * @dev Modifier to check if an application exists.
     * @param appId The ID of the application.
     */
    modifier appIsExist(uint256 appId) {
        require(applications[appId] != address(0), "Trade: app not exist");
        _;
    }

    /**
     * @dev Modifier to check if the caller is the admin of the application.
     * @param appId The ID of the application.
     */
    modifier onlyAppAdmin(uint256 appId) {
        require(applications[appId] == msg.sender, "Trade: only app admin");
        _;
    } 

    /**
     * @dev Creates a new application with the default fee.
     */
    function createApp() public {
        create(DEFAULT_APP_FEE, msg.sender);
    }

    /**
     * @dev Creates a new application with a custom fee.
     * @param fee The fee for the application.
     * @param app The address of the application.
     */
    function create(uint256 fee, address app) public {
        require(app != address(0), "Trade: invalid app address");
        require(fee < 1 ether, "Trade: fee must be less than 100%");
        uint256 appId = idIndex;
        applications[appId] = app;
        appFee[appId] = fee;
        idIndex = appId + 1;
    }

    /**
     * @dev Buys ERC1155 tokens from the Bodhi contract.
     * @param appId The ID of the application.
     * @param assetId The ID of the asset.
     * @param amount The amount of tokens to buy.
     */
    function buy(uint256 appId, uint256 assetId, uint256 amount) public payable appIsExist(appId) {
        uint256 value = msg.value;
        uint256 price_with_fee = getBuyPriceAfterFee(appId, assetId, amount);
        require(value >= price_with_fee, "Trade: insufficient fund");

        uint256 price = bodhi.getBuyPriceAfterFee(assetId, amount);
        bodhi.buy{value: price}(assetId, amount);

        bodhi.safeTransferFrom(address(this), msg.sender, assetId, amount, "");
        emit Buy(appId, assetId, msg.sender, amount, price, price_with_fee - price);
        
        appRevenue[appId] += price_with_fee - price;
    }

    /**
     * @dev Sells ERC1155 tokens to the Bodhi contract.
     * @notice Before selling, the caller must approve(bodhi.setApprovalForAll) the contract to transfer the tokens.
     * @param appId The ID of the application.
     * @param assetId The ID of the asset.
     * @param amount The amount of tokens to sell.
     */
    function sell(uint appId, uint256 assetId, uint256 amount) public appIsExist(appId) {
        require(bodhi.balanceOf(msg.sender, assetId) >= amount, "Trade: insufficient balance");
        bodhi.safeTransferFrom(msg.sender, address(this), assetId, amount, "");

        uint256 price = bodhi.getSellPrice(assetId, amount);
        uint256 price_after_fee = bodhi.getSellPriceAfterFee(assetId, amount);
        uint256 current_balance = address(this).balance;
        bodhi.sell(assetId, amount);
        require(address(this).balance >= current_balance + price_after_fee, "Trade: balance mismatch");

        uint256 app_fee = getAppFee(appId, price);
        uint256 return_fund = price_after_fee - app_fee;
        require(app_fee + return_fund == price_after_fee, "Trade: price overflow");
        (bool success, ) = payable(msg.sender).call{value: return_fund}("");
        require(success, "Trade: transfer failed");
        emit Sell(appId, assetId, msg.sender, amount, price_after_fee, app_fee);

        appRevenue[appId] += app_fee;
    }

    /**
     * @dev Calculates the buy price of ERC1155 tokens after applying the application fee.
     * @param appId The ID of the application.
     * @param assetId The ID of the asset.
     * @param amount The amount of tokens to buy.
     * @return The buy price after applying the fee.
     */
    function getBuyPriceAfterFee(uint256 appId, uint256 assetId, uint256 amount) 
        public 
        view 
        appIsExist(appId) 
        returns (uint256) 
    {
        uint256 fee = appFee[appId];
        uint256 price = bodhi.getBuyPrice(assetId, amount);
        uint256 total_fee = price * (fee + CREATOR_FEE_PERCENT) / 1 ether;
        return price + total_fee;
    }

    /**
     * @dev Calculates the sell price of ERC1155 tokens after applying the application fee.
     * @param appId The ID of the application.
     * @param assetId The ID of the asset.
     * @param amount The amount of tokens to sell.
     * @return The sell price after applying the fee.
     */
    function getSellPriceAfterFee(uint256 appId, uint256 assetId, uint256 amount) 
        public 
        view 
        appIsExist(appId) 
        returns (uint256) 
    {
        uint256 fee = appFee[appId];
        uint256 price = bodhi.getSellPrice(assetId, amount);
        uint256 total_fee = price * (fee + CREATOR_FEE_PERCENT) / 1 ether;
        return price - total_fee;
    }

    /**
     * @dev Calculates the application fee for a given price.
     * @param appId The ID of the application.
     * @param price The price of the asset.
     * @return The application fee.
     */
    function getAppFee(uint256 appId, uint256 price) 
        public 
        view 
        appIsExist(appId) 
        returns (uint256) 
    {
        return price * appFee[appId] / 1 ether;
    }

    receive() external payable {}
    fallback() external payable {}

    /**
     * @dev Withdraws the accumulated revenue for an application.
     * @param appId The ID of the application.
     */
    function withdrawFee(uint256 appId) public appIsExist(appId) onlyAppAdmin(appId){
        uint256 revenue = appRevenue[appId];
        require(revenue > 0, "Trade: no revenue to withdraw");
        appRevenue[appId] = 0;
        (bool success, ) = payable(msg.sender).call{value: revenue}("");
        require(success, "Trade: transfer failed");
    }
}