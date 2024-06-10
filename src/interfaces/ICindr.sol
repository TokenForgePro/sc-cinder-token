// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICindr is IERC20 {
    /**
     * @dev Error for insufficient token balance.
     * @param account The address of the account with insufficient balance.
     * @param balance The current token balance of the account.
     * @param required The required token balance for the operation.
     */
    error InsufficientBalance(
        address account,
        uint256 balance,
        uint256 required
    );

    /**
     * @dev Error for insufficient reflection balance.
     * @param account The address of the account with insufficient reflection balance.
     * @param balance The current reflection balance of the account.
     * @param required The required reflection balance for the operation.
     */
    error InsufficientReflectionBalance(
        address account,
        uint256 balance,
        uint256 required
    );

    /**
     * @dev Emitted when the minimum number of tokens before initiating a swap is updated
     * @param minTokensBeforeSwap The new minimum number of tokens before initiating a swap
     */
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);

    /**
     * @dev Emitted when the swap and liquify feature is enabled or disabled
     * @param enabled A boolean indicating whether the swap and liquify feature is enabled
     */
    event SwapAndLiquifyEnabledUpdated(bool enabled);

    /**
     * @dev Emitted when tokens are swapped and liquidity is added
     * @param tokensSwapped The amount of tokens that were swapped
     * @param ethReceived The amount of ETH received from the swap
     * @param tokensIntoLiquidity The amount of tokens that were added to the liquidity pool
     */
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    /**
     * @dev Checks if an account is excluded from receiving rewards.
     * @param account The address to check.
     */
    function isExcludedFromReward(address account) external view returns (bool);

    /**
     * @dev Returns the total fees collected.
     */
    function totalFees() external view returns (uint256);

    /**
     * @dev Delivers the specified amount of tokens to the sender.
     * @param tAmount The amount of tokens to deliver.
     */
    function deliver(uint256 tAmount) external;

    /**
     * @dev Returns the reflection from the specified token amount.
     * @param tAmount The amount of tokens.
     * @param deductTransferFee Whether to deduct the transfer fee.
     */
    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) external view returns (uint256);

    /**
     * @dev Returns the token amount from the specified reflection amount.
     * @param rAmount The amount of reflection.
     */
    function tokenFromReflection(
        uint256 rAmount
    ) external view returns (uint256);

    /**
     * @dev Excludes an account from receiving rewards.
     * @param account The address to exclude.
     */
    function excludeFromReward(address account) external;

    /**
     * @dev Includes an account in receiving rewards.
     * @param account The address to include.
     */
    function includeInReward(address account) external;

    /**
     * @dev Excludes an account from paying fees.
     * @param account The address to exclude.
     */
    function excludeFromFee(address account) external;

    /**
     * @dev Includes an account in paying fees.
     * @param account The address to include.
     */
    function includeInFee(address account) external;

    /**
     * @dev Sets the tax fee percentage.
     * @param _taxFee The tax fee percentage.
     */
    function setTaxFeePercent(uint16 _taxFee) external;

    /**
     * @dev Sets the burn fee percentage.
     * @param _burnFee The burn fee percentage.
     */
    function setBurnFeePercent(uint16 _burnFee) external;

    /**
     * @dev Sets the liquidity fee percentage.
     * @param _liquidityFee The liquidity fee percentage.
     */
    function setLiquidityFeePercent(uint16 _liquidityFee) external;

    /**
     * @dev Sets the marketing fee percentage.
     * @param _marketingFee The marketing fee percentage.
     */
    function setMarketingFeePercent(uint16 _marketingFee) external;

    /**
     * @dev Sets the maximum transaction percentage.
     * @param maxTxPercent The maximum transaction percentage.
     */
    function setMaxTxPercent(uint256 maxTxPercent) external;

    /**
     * @dev Enables or disables swap and liquify.
     * @param _enabled Whether swap and liquify is enabled.
     */
    function setSwapAndLiquifyEnabled(bool _enabled) external;

    /**
     * @dev Receives Ether to the contract.
     */
    receive() external payable;
}
