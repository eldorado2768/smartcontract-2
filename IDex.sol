// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// The interface for our mock DEX contracts.
interface IDex {
    // Returns the current reserves of the two tokens in the pool.
    function getReserves() external view returns (uint256 reserveA, uint256 reserveB);

    // Executes a mock swap from tokenIn to tokenOut.
    function buyToken(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut);

    // Gets the balance of a specific token held by the DEX.
    function getBalance(address _tokenAddress) external view returns (uint256);
}
