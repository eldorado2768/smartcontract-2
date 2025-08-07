// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// This file defines the interfaces required for our contract to interact with Aave V3's flash loan functionality.

// The IFlashLoanSimpleReceiver interface is what our contract must implement
// so that the Aave LendingPool knows what function to call after it has sent us the flash loan.
interface IFlashLoanSimpleReceiver {
    /**
     * @notice Aave will call this function on our contract after granting a flash loan.
     * The flash loaned funds will be available in the contract at this point.
     * @param assets The array of tokens loaned.
     * @param amounts The array of amounts loaned.
     * @param premium The array of premiums (fees) to be repaid.
     * @param initiator The address that initiated the flash loan.
     * @param params Additional data passed to the flash loan.
     * @return bool Must return true for a successful loan repayment.
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

// The ILendingPool interface defines the functions we need to call on the Aave LendingPool contract
// to request a flash loan.
interface ILendingPool {
    /**
     * @notice Requests a flash loan from the Lending Pool.
     * @param receiverAddress The address of the contract that will receive the funds and execute the operation.
     * @param assets The array of token addresses to loan.
     * @param amounts The array of amounts to loan.
     * @param modes The debt mode (0 = no debt, 1 = variable, 2 = stable). We use 0 for a flash loan.
     * @param onBehalfOf The address that will get the debt. We use address(0) for a simple flash loan.
     * @param params Additional data to be passed to the receiver contract.
     * @param referralCode A referral code if applicable.
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

