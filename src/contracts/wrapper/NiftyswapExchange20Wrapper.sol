// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapExchange20Wrapper} from "../interfaces/INiftyswapExchange20Wrapper.sol";
import {INiftyswapExchange20} from "../interfaces/INiftyswapExchange20.sol";
import {IERC20} from "@0xsequence/erc-1155/contracts/interfaces/IERC20.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

error InvalidRecipient();

/**
 * A wrapper for the Niftyswap exchange contract that when swapping for ERC-1155
 * allows the ERC-20 refund to be sent to a recipient other than the token recipient.
 */
contract NiftyswapExchange20Wrapper is INiftyswapExchange20Wrapper, IERC1155TokenReceiver, IERC165 {
    // onReceive function signatures
    bytes4 internal constant ERC1155_RECEIVED_VALUE = 0xf23a6e61;
    bytes4 internal constant ERC1155_BATCH_RECEIVED_VALUE = 0xbc197c81;

    address private tokenRecipient;

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
    ) external override returns (uint256[] memory currencySold) {
        if (_currencyRecipient == address(0) || _tokenRecipient == address(0)) {
            revert InvalidRecipient();
        }

        // Obtain currency for Niftyswap
        address currencyAddress = INiftyswapExchange20(_exchange20Address).getCurrencyInfo();
        TransferHelper.safeTransferFrom(currencyAddress, msg.sender, address(this), _maxCurrency);
        TransferHelper.safeApprove(currencyAddress, _exchange20Address, _maxCurrency);

        // Store recipient for forwarding
        tokenRecipient = _tokenRecipient;

        // Call NiftyswapExchange20 contract
        currencySold = INiftyswapExchange20(_exchange20Address).buyTokens(
            _tokenIds,
            _tokensBoughtAmounts,
            _maxCurrency,
            _deadline,
            address(this), // _tokenRecipient
            _extraFeeRecipients,
            _extraFeeAmounts
        );

        // Clear recipient
        delete tokenRecipient;

        // Send currency refund to currency recipient
        uint256 balance = IERC20(currencyAddress).balanceOf(address(this));
        TransferHelper.safeTransfer(currencyAddress, _currencyRecipient, balance);
    }

    /**
     * Receive ERC-1155 tokens and forward to token recipient.
     * @param _ids      An array containing ids of each Token being transferred
     * @param _amounts  An array containing amounts of each Token being transferred
     * @param _data     Additional data to forward to recipient
     * @return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)")
     */
    function onERC1155BatchReceived(
        address, // _operator,
        address, // from
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public override returns (bytes4) {
        if (tokenRecipient == address(0)) {
            revert InvalidRecipient();
        }
        // Forward to token recipient
        IERC1155(msg.sender).safeBatchTransferFrom(address(this), tokenRecipient, _ids, _amounts, _data);
        return ERC1155_BATCH_RECEIVED_VALUE;
    }

    /**
     * Receive ERC-1155 tokens and forward to token recipient.
     * @param _id      Id of Token being transferred
     * @param _amount  Amounts of Token being transferred
     * @param _data     Additional data to forward to recipient
     * @return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")
     */
    function onERC1155Received(address, address, uint256 _id, uint256 _amount, bytes memory _data)
        public
        override
        returns (bytes4)
    {
        if (tokenRecipient == address(0)) {
            revert InvalidRecipient();
        }
        // Forward to token recipient
        IERC1155(msg.sender).safeTransferFrom(address(this), tokenRecipient, _id, _amount, _data);
        return ERC1155_RECEIVED_VALUE;
    }

    /**
     * @notice Indicates which interfaces the contract implements.
     * @param  interfaceID The ERC-165 interface ID that is queried for support.
     * @return Whether a given interface is supported
     */
    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return interfaceID == type(INiftyswapExchange20Wrapper).interfaceId
            || interfaceID == type(IERC1155TokenReceiver).interfaceId || interfaceID == type(IERC165).interfaceId;
    }
}
