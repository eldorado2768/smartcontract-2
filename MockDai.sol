// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// A simple mock DAI contract for testing.
contract MockDai is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") {
        _mint(msg.sender, 1000000 * 1e18); // Mint a large supply to the deployer
    }
}
