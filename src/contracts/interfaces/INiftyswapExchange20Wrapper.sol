// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

interface INiftyswapExchange20Wrapper {
    /**
     * @notice Convert currency tokens to Tokens _id and transfers Tokens to recipient.
     * @dev User specifies MAXIMUM inputs (_maxCurrency) and EXACT outputs.
     * @dev Assumes that all trades will be successful, or revert the whole tx.
     * @dev Exceeding currency tokens sent will be refunded to the currency recipient.
     * @dev Sorting IDs is mandatory for efficient way of preventing duplicated IDs (which would lead to exploit)
     * @param _exchange20Address   Address of the NiftyswapExchange20 contract
     * @param _tokenIds            Array of Tokens ID that are bought
     * @param _tokensBoughtAmounts Amount of Tokens id bought for each corresponding Token id in _tokenIds
     * @param _maxCurrency         Total maximum amount of currency tokens to spend for all Token ids
     * @param _deadline            Timestamp after which this transaction will be reverted
     * @param _tokenRecipient      The address that receives output Tokens
     * @param _currencyRecipient   The address that receives the refund of currency tokens
     * @param _extraFeeRecipients  Array of addresses that will receive extra fee
     * @param _extraFeeAmounts     Array of amounts of currency that will be sent as extra fee
     * @return currencySold How much currency was actually sold.
     */
    function buyTokens(
        address _exchange20Address,
        uint256[] memory _tokenIds,
        uint256[] memory _tokensBoughtAmounts,
        uint256 _maxCurrency,
        uint256 _deadline,
        address _tokenRecipient,
        address _currencyRecipient,
        address[] memory _extraFeeRecipients,
        uint256[] memory _extraFeeAmounts
    ) external returns (uint256[] memory);
}
