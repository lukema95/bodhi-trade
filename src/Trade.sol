// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ERC1155.sol";
import "./interface/IBodhi.sol";

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

    constructor(address _bodhi) {
        bodhi = IBodhi(_bodhi);
    }

    modifier appIsExist(uint256 appId) {
        require(applications[appId] != address(0), "Trade: app not exist");
        _;
    }

    modifier onlyAppAdmin(uint256 appId) {
        require(applications[appId] == msg.sender, "Trade: only app admin");
        _;
    } 

    function createApp() public {
        create(DEFAULT_APP_FEE, msg.sender);
    }

    function create(uint256 fee, address app) public {
        require(app != address(0), "Trade: invalid app address");
        require(fee < 1 ether, "Trade: fee must be less than 100%");
        uint256 appId = idIndex;
        applications[appId] = app;
        appFee[appId] = fee;
        idIndex = appId + 1;
    }

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

    function sell(uint appId, uint256 assetId, uint256 amount) public appIsExist(appId) {
        require(bodhi.balanceOf(msg.sender, assetId) >= amount, "Trade: insufficient balance");
        bodhi.safeTransferFrom(msg.sender, address(this), assetId, amount, "");

        uint256 price = bodhi.getSellPriceAfterFee(assetId, amount);
        uint256 current_balance = address(this).balance;
        bodhi.sell(assetId, amount);
        require(address(this).balance >= current_balance + price, "Trade: balance mismatch");

        uint256 app_fee = getAppFee(appId, price);
        uint256 return_fund = price - app_fee;
        require(app_fee + return_fund == price, "Trade: price overflow");
        (bool success, ) = payable(msg.sender).call{value: return_fund}("");
        require(success, "Trade: transfer failed");
        emit Sell(appId, assetId, msg.sender, amount, price, app_fee);

        appRevenue[appId] += app_fee;
    }

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

    function getSellPriceAfterFee(uint256 appId, uint256 assetId, uint256 amount) 
        public 
        view 
        appIsExist(appId) 
        returns (uint256) 
    {
        uint256 fee = appFee[appId];
        uint256 price = bodhi.getSellPriceAfterFee(assetId, amount);
        uint256 total_fee = price * fee / 1 ether;
        return price - total_fee;
    }

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

    function withdrawFee(uint256 appId) public appIsExist(appId) onlyAppAdmin(appId){
        payable(msg.sender).transfer(appRevenue[appId]);
    }

}