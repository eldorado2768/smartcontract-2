/ SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IDex.sol";

// A simple mock DEX contract for testing purposes.
contract MockDEX is IDex {
    // Reserves for two tokens
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;

    constructor(address _tokenA, address _tokenB, uint256 _initialReserveA, uint256 _initialReserveB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        reserveA = _initialReserveA;
        reserveB = _initialReserveB;
    }

    // Returns the current reserves.
    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }
    
    // A simple mock swap function.
    function buyToken(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {
        uint256 fee = amountIn / 1000 * 3; // 0.3% fee
        uint256 amountInAfterFee = amountIn - fee;

        if (tokenIn == address(tokenA) && tokenOut == address(tokenB)) {
            amountOut = (amountInAfterFee * reserveB) / (reserveA + amountInAfterFee);
            reserveA += amountInAfterFee;
            reserveB -= amountOut;
        } else if (tokenIn == address(tokenB) && tokenOut == address(tokenA)) {
            amountOut = (amountInAfterFee * reserveA) / (reserveB + amountInAfterFee);
            reserveB += amountInAfterFee;
            reserveA -= amountOut;
        } else {
            revert("Invalid tokens for swap");
        }
    }

    // New function to fulfill the IDex interface.
    // In a real DEX, this would return the contract's balance of the specified token.
    function getBalance(address _tokenAddress) external view returns (uint256) {
        if (_tokenAddress == address(tokenA)) {
            return reserveA;
        } else if (_tokenAddress == address(tokenB)) {
            return reserveB;
        } else {
            return 0;
        }
    }
}
