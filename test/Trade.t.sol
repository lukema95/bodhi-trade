pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Trade} from '../src/Trade.sol';
import {Bodhi} from '../src/Bodhi.sol';

contract TradeTest is Test {
    receive() external payable {}
    fallback() external payable {}

    Bodhi bodhi;
    Trade trade;

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);

    function setUp() public {
        bodhi = new Bodhi();
        trade = new Trade(address(bodhi));
    }

    function test_createApp() public {
        trade.createApp();
        assertEq(trade.applications(0), address(this));
    }

    function test_create() public {
        trade.create(0.02 ether, address(this));
        assertEq(trade.applications(0), address(this));
    }

    function test_buy() public {
        vm.prank(user1);
        trade.createApp();
        
        vm.prank(user2);
        bodhi.create("arTxId");

        uint256 price = bodhi.getBuyPrice(0, 1 ether);
        uint256 priceAfterFee = trade.getBuyPriceAfterFee(0, 0, 1 ether);
        vm.deal(user3, priceAfterFee);
        vm.prank(user3);
        trade.buy{value: priceAfterFee}(0, 0, 1 ether);
        uint256 afterAssetBalance = bodhi.balanceOf(user3, 0);
        assertEq(afterAssetBalance, 1 ether);

        uint256 appRevenue = trade.appRevenue(0);
        uint256 appFee = trade.getAppFee(0, price);
        assertEq(appRevenue, appFee);

        vm.prank(user1);
        trade.withdrawFee(0);
        uint256 afterBalance = address(user1).balance;
        assertEq(afterBalance, appRevenue);

        uint256 afterAppRevenue = trade.appRevenue(0);
        assertEq(afterAppRevenue, 0);
    }

    function test_sell() public {
        test_buy();

        vm.prank(user3);
        bodhi.setApprovalForAll(address(trade), true);

        uint256 price = bodhi.getSellPrice(0, 1 ether);
        uint256 priceAfterFee = trade.getSellPriceAfterFee(0, 0, 1 ether);
        uint256 beforeBalance = address(user3).balance;
        vm.prank(user3);
        trade.sell(0, 0, 1 ether);
        uint256 afterBalance = address(user3).balance;
        assertEq(afterBalance, beforeBalance + priceAfterFee);

        uint256 appRevenue = trade.appRevenue(0);
        uint256 appFee = trade.getAppFee(0, price);
        assertEq(appRevenue, appFee);
    }
}
