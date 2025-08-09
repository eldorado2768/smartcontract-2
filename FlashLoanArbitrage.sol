// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//Note: environment is injected-provider Metamask

// Corrected import paths
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IDex.sol";
import "./AaveV3FlashLoan.sol";

// This contract will execute a flash loan arbitrage on our two mock DEXes.
// The core logic is within the `executeOperation` function, which is called
// by Aave's LendingPool after the flash loan is received.
contract FlashLoanArbitrage is IFlashLoanSimpleReceiver {
    using SafeERC20 for IERC20;

    // Aave's Lending Pool address
    ILendingPool public immutable LENDING_POOL;

    // The two DEXes we will be using for the arbitrage
    IDex public immutable DEX_A;
    IDex public immutable DEX_B;

    // The token addresses for DAI and USDC
    address public immutable DAI;
    address public immutable USDC;

    // The address of the owner/caller who can trigger the arbitrage
    address public immutable owner;

    event ArbitrageExecuted(
        uint256 indexed profit,
        uint256 indexed loanAmount,
        uint256 fee
    );
    event ProfitWithdrawn(uint256 amount);

    constructor(
        address _lendingPool,
        address _dexA,
        address _dexB,
        address _dai,
        address _usdc
    ) {
        LENDING_POOL = ILendingPool(_lendingPool);
        DEX_A = IDex(_dexA);
        DEX_B = IDex(_dexB);
        DAI = _dai;
        USDC = _usdc;
        owner = msg.sender;
    }

    /**
     * @notice This is the main entry point for the off-chain bot to trigger the arbitrage.
     * It requests a flash loan from Aave and specifies this contract as the receiver.
     * @param _loanAmount The amount of DAI to borrow for the flash loan.
     */
    function startArbitrage(uint256 _loanAmount) external {
        require(msg.sender == owner, "Only the owner can start an arbitrage");
        
        // This is a simple flash loan request for DAI.
        // It will call back to this contract's `executeOperation` function.
        address[] memory assets = new address[](1);
        assets[0] = DAI;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _loanAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // 0 = no debt, 1 = variable, 2 = stable

        address onBehalfOf = address(this); // The contract itself receives the funds
        bytes memory params = ""; // No extra parameters needed

        uint16 referralCode = 0;

        // Perform the flash loan, which will trigger the `executeOperation` function
        LENDING_POOL.flashLoan(
            onBehalfOf,
            assets,
            amounts,
            modes,
            address(0), // Simple flash loan doesn't need to return to a different address
            params,
            referralCode
        );
    }

    /*
     * @notice This is the callback function from the Aave Lending Pool.
     * The flash loaned funds are available inside this function.
     * The arbitrage logic must be contained here.
     * @param assets The array of tokens loaned.
     * @param amounts The array of amounts loaned.
     * @param premium The array of premiums to repay.
     * @param initiator The address that initiated the flash loan.
     * @param params Additional data passed to the flash loan.
     * @return bool Must return true for a successful loan repayment.
     */
    function executeOperation(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory premium,
        address,
        bytes calldata
    ) external returns (bool) {
        // Here, the contract receives the `amounts` of `assets`
        uint256 loanAmount = amounts[0];
        uint256 flashLoanFee = premium[0];
        uint256 amountToRepay = loanAmount + flashLoanFee;

        // Arbitrage Logic: Perform swaps based on the best path
        // We'll calculate the potential profit based on the current reserves
        // (This would typically happen off-chain, but we can do a quick check here as well)

        // Get current reserves for DAI and USDC from both DEXes
        (uint256 dexADaiRes, uint256 dexAUsdcRes) = DEX_A.getReserves();
        (uint256 dexBDaiRes, uint256 dexBUsdcRes) = DEX_B.getReserves();

        // Calculate potential profits for both paths
        uint256 profitPath1 = calculateProfit(loanAmount, dexADaiRes, dexAUsdcRes, dexBDaiRes, dexBUsdcRes, flashLoanFee);
        uint256 profitPath2 = calculateProfit(loanAmount, dexBDaiRes, dexBUsdcRes, dexADaiRes, dexAUsdcRes, flashLoanFee);

        // Path 1: DAI -> USDC on DEX A, then USDC -> DAI on DEX B
        if (profitPath1 > profitPath2) {
            uint256 usdcOut = DEX_A.buyToken(DAI, USDC, loanAmount);
            IERC20(DAI).approve(address(DEX_A), loanAmount);
            IERC20(USDC).safeTransfer(address(DEX_A), usdcOut); // This is mock transfer
            
            uint256 daiOut = DEX_B.buyToken(USDC, DAI, usdcOut);
            IERC20(USDC).approve(address(DEX_B), usdcOut);
            IERC20(DAI).safeTransfer(address(DEX_B), daiOut); // This is mock transfer
            
            // Repay the loan
            IERC20(DAI).safeTransfer(msg.sender, amountToRepay); // This is a mock repayment
            
            // The profit would be `daiOut - amountToRepay`
            // In the real version, we'd transfer the profit to the owner
            uint256 profit = daiOut - amountToRepay;
            emit ArbitrageExecuted(profit, loanAmount, flashLoanFee);
        } 
        // Path 2: DAI -> USDC on DEX B, then USDC -> DAI on DEX A
        else if (profitPath2 > 0) {
            uint256 usdcOut = DEX_B.buyToken(DAI, USDC, loanAmount);
            IERC20(DAI).approve(address(DEX_B), loanAmount);
            IERC20(USDC).safeTransfer(address(DEX_B), usdcOut); // This is mock transfer
            
            uint256 daiOut = DEX_A.buyToken(USDC, DAI, usdcOut);
            IERC20(USDC).approve(address(DEX_A), usdcOut);
            IERC20(DAI).safeTransfer(address(DEX_A), daiOut); // This is mock transfer

            // Repay the loan
            IERC20(DAI).safeTransfer(msg.sender, amountToRepay); // This is a mock repayment
            
            uint256 profit = daiOut - amountToRepay;
            emit ArbitrageExecuted(profit, loanAmount, flashLoanFee);
        } else {
            // No profitable path found, just repay the loan
            IERC20(DAI).safeTransfer(msg.sender, amountToRepay); // This is a mock repayment
        }
        
        // This must return true to indicate successful repayment to Aave
        return true;
    }

    /**
     * @notice Helper function to calculate the profit for a given path.
     * This logic is similar to our local app.
     */
    function calculateProfit(
        uint256 _loanAmount,
        uint256 _reserveInDEX1,
        uint256 _reserveOutDEX1,
        uint256 _reserveInDEX2,
        uint256 _reserveOutDEX2,
        uint256 _flashLoanFee
    ) internal pure returns (uint256) {
        uint256 swapFeeNumerator = 3;
        uint256 swapFeeDenominator = 1000;
        
        uint256 amountInAfterFeeDEX1 = _loanAmount * (swapFeeDenominator - swapFeeNumerator) / swapFeeDenominator;
        uint256 amountOutDEX1 = (amountInAfterFeeDEX1 * _reserveOutDEX1) / (_reserveInDEX1 + amountInAfterFeeDEX1);

        uint256 amountInAfterFeeDEX2 = amountOutDEX1 * (swapFeeDenominator - swapFeeNumerator) / swapFeeDenominator;
        uint256 amountOutDEX2 = (amountInAfterFeeDEX2 * _reserveOutDEX2) / (_reserveInDEX2 + amountInAfterFeeDEX2);

        uint256 totalRepayment = _loanAmount + _flashLoanFee;
        
        if (amountOutDEX2 > totalRepayment) {
            return amountOutDEX2 - totalRepayment;
        } else {
            return 0;
        }
    }

    /**
     * @notice A simple function for the owner to withdraw any profit left in the contract.
     */
    function withdrawProfit() external {
        require(msg.sender == owner, "Only the owner can withdraw profit");
        uint256 daiBalance = IERC20(DAI).balanceOf(address(this));
        if (daiBalance > 0) {
            IERC20(DAI).safeTransfer(owner, daiBalance);
            emit ProfitWithdrawn(daiBalance);
        }
    }
}

