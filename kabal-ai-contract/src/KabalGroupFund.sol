// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract GroupTokenSwap {
    ISwapRouter public immutable swapRouter;
    uint24 public constant poolFee = 3000;

    struct Group {
        address[] members;
        mapping(address => uint256) contributions;
        uint256 totalValueLocked;
        mapping(address => uint256) tokenBalances;
    }

    mapping(uint256 => Group) public groups;
    uint256 public nextGroupId;

    event GroupCreated(uint256 groupId);
    event TokenSwapped(uint256 groupId, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event FundsWithdrawn(uint256 groupId, address member, uint256 amount);

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter;
    }

    function createGroup() external returns (uint256 groupId) {
        groupId = nextGroupId++;
        emit GroupCreated(groupId);
    }

    function joinGroup(uint256 groupId, address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);

        Group storage group = groups[groupId];

        if (group.contributions[msg.sender] == 0) {
            group.members.push(msg.sender);
        }

        group.contributions[msg.sender] += amount;
        group.totalValueLocked += amount;
    }

    function swapTokens(
        uint256 groupId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external {
        Group storage group = groups[groupId];
        require(group.totalValueLocked >= amountIn, "Insufficient group funds");

        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = swapRouter.exactInputSingle(params);
        group.totalValueLocked -= amountIn;
        group.tokenBalances[tokenOut] += amountOut;

        emit TokenSwapped(groupId, tokenIn, tokenOut, amountIn, amountOut);

        distributeTokens(groupId, tokenOut);
    }

    function distributeTokens(uint256 groupId, address token) internal {
        Group storage group = groups[groupId];
        uint256 totalTokenBalance = group.tokenBalances[token];
        require(totalTokenBalance > 0, "No tokens to distribute");

        for (uint256 i = 0; i < group.members.length; i++) {
            address member = group.members[i];
            uint256 share = (group.contributions[member] * totalTokenBalance) / group.totalValueLocked;
            if (share > 0) {
                group.tokenBalances[token] -= share;
                TransferHelper.safeTransfer(token, member, share);
            }
        }
    }

    function withdrawFunds(uint256 groupId, address token, uint256 amount) external {
        Group storage group = groups[groupId];
        require(group.contributions[msg.sender] >= amount, "Insufficient contribution to withdraw");

        group.contributions[msg.sender] -= amount;
        group.totalValueLocked -= amount;

        TransferHelper.safeTransfer(token, msg.sender, amount);
        emit FundsWithdrawn(groupId, msg.sender, amount);

        recalculateAllocations(groupId);
    }

    function recalculateAllocations(uint256 groupId) internal {
        Group storage group = groups[groupId];
        uint256 totalLocked = group.totalValueLocked;

        for (uint256 i = 0; i < group.members.length; i++) {
            address member = group.members[i];
            group.contributions[member] = (group.contributions[member] * 10000) / totalLocked;
        }
    }
}
