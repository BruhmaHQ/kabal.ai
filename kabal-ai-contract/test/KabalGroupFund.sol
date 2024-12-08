// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/KabalGroupFund.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract GroupTokenSwapTest is Test {
    GroupTokenSwap groupTokenSwap;
    MockERC20 tokenA;
    MockERC20 tokenB;
    ISwapRouter swapRouter;

    function setUp() public {
        swapRouter = ISwapRouter(/* Uniswap router address */);
        groupTokenSwap = new GroupTokenSwap(swapRouter);
        tokenA = new MockERC20("TokenA", "TKA", 1_000_000 * 10 ** 18);
        tokenB = new MockERC20("TokenB", "TKB", 1_000_000 * 10 ** 18);
    }

    function testJoinGroup() public {
        uint256 groupId = groupTokenSwap.createGroup();
        tokenA.approve(address(groupTokenSwap), 1000);
        groupTokenSwap.joinGroup(groupId, address(tokenA), 1000);
        assertEq(groupTokenSwap.groups(groupId).totalValueLocked, 1000);
    }

    function testSwapAndDistribute() public {
        uint256 groupId = groupTokenSwap.createGroup();
        tokenA.approve(address(groupTokenSwap), 1000);
        groupTokenSwap.joinGroup(groupId, address(tokenA), 1000);

        tokenB.transfer(address(groupTokenSwap), 500);
        groupTokenSwap.swapTokens(groupId, address(tokenA), address(tokenB), 500, 0);
        assertEq(tokenB.balanceOf(address(this)), 500);
    }

    function testWithdraw() public {
        uint256 groupId = groupTokenSwap.createGroup();
        tokenA.approve(address(groupTokenSwap), 1000);
        groupTokenSwap.joinGroup(groupId, address(tokenA), 1000);
        groupTokenSwap.withdrawFunds(groupId, address(tokenA), 500);
        assertEq(tokenA.balanceOf(address(this)), 500);
    }
}
