// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155.sol";
import {ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {IERC1155FloorWrapper, IERC1155TokenReceiver} from "../interfaces/IERC1155FloorWrapper.sol";
import {IERC1155Metadata} from "../interfaces/IERC1155Metadata.sol";
import {IDelegatedERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";
import {WrapperErrors} from "../utils/WrapperErrors.sol";

/**
 * @notice Allows users to wrap any amount of a ERC-1155 token with a 1:1 ratio.
 * Therefore each ERC-1155 within a collection can be treated as if fungible.
 */
contract ERC1155FloorWrapper is IERC1155FloorWrapper, ERC1155MintBurn, IERC1155Metadata, WrapperErrors {
    address internal immutable factory;
    address public tokenAddr;
    // This contract only supports a single token id
    uint256 public constant TOKEN_ID = 0;

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _tokenAddr) external {
        if (msg.sender != factory || tokenAddr != address(0)) {
            revert InvalidInitialization();
        }
        tokenAddr = _tokenAddr;
    }

    /**
     * Prevent invalid method calls.
     */
    fallback() external {
        revert UnsupportedMethod();
    }

    /**
     * Accepts ERC-1155 tokens to wrap and wrapped ERC-1155 tokens to unwrap.
     * @param id The ID of the token being transferred.
     * @param amount The amount of tokens being transferred.
     * @param data Additional data formatted as DepositRequestObj or WithdrawRequestObj.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155Received(address, address, uint256 id, uint256 amount, bytes calldata data)
        external
        returns (bytes4)
    {
        if (msg.sender == tokenAddr) {
            // Deposit
            uint256[] memory ids = new uint256[](1);
            ids[0] = id;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;
            _deposit(ids, amounts, data);
        } else if (msg.sender == address(this)) {
            // Withdraw
            _withdraw(amount, data);
        } else {
            revert InvalidERC1155Received();
        }

        return IERC1155TokenReceiver.onERC1155Received.selector;
    }

    /**
     * Accepts ERC-1155 tokens to wrap and wrapped ERC-1155 tokens to unwrap.
     * @param ids The IDs of the tokens being transferred.
     * @param amounts The amounts of tokens being transferred.
     * @param data Additional data formatted as DepositRequestObj or WithdrawRequestObj.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public returns (bytes4) {
        if (msg.sender == tokenAddr) {
            // Deposit
            _deposit(ids, amounts, data);
        } else if (msg.sender == address(this)) {
            // Withdraw
            if (ids.length != 1) {
                revert InvalidERC1155Received();
            }
            // Either ids[0] == TOKEN_ID or amounts[0] == 0
            _withdraw(amounts[0], data);
        } else {
            revert InvalidERC1155Received();
        }

        return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }

    /**
     * Wrap deposited ERC-1155 tokens.
     * @param tokenIds The ERC-1155 token ids deposited.
     * @param tokenAmounts The amount of each token deposited.
     * @param data Data received during deposit.
     */
    function _deposit(
        uint256[] memory tokenIds, //FIXME Use calldata with _depositBatch
        uint256[] memory tokenAmounts, //FIXME Use calldata with _depositBatch
        bytes calldata data
    ) private {
        emit TokensDeposited(tokenIds, tokenAmounts);

        uint256 total;
        uint256 length = tokenIds.length;
        for (uint256 i; i < length;) {
            total += tokenAmounts[i];
            unchecked {
                // Can never overflow
                i++;
            }
        }

        DepositRequestObj memory obj;
        (obj) = abi.decode(data, (DepositRequestObj));
        if (obj.recipient == address(0)) {
            // Don't allow deposits to the zero address
            revert InvalidDepositRequest();
        }

        _mint(obj.recipient, TOKEN_ID, total, obj.data);
    }

    /**
     * Unwrap withdrawn ERC-1155 tokens.
     * @param amount The amount of wrapped tokens received for withdraw.
     * @param data Data received during unwrap ERC-1155 receiver request.
     */
    function _withdraw(uint256 amount, bytes calldata data) private {
        _burn(address(this), TOKEN_ID, amount);

        WithdrawRequestObj memory obj;
        (obj) = abi.decode(data, (WithdrawRequestObj));
        if (obj.recipient == address(0)) {
            // Don't allow withdraws to the zero address
            revert InvalidWithdrawRequest();
        }

        uint256 total;
        uint256 length = obj.tokenAmounts.length;
        for (uint256 i; i < length;) {
            total += obj.tokenAmounts[i];
            unchecked {
                i++;
            }
        }

        if (total != amount) {
            revert InvalidWithdrawRequest();
        }

        IERC1155(tokenAddr).safeBatchTransferFrom(
            address(this), obj.recipient, obj.tokenIds, obj.tokenAmounts, obj.data
        );
        emit TokensWithdrawn(obj.tokenIds, obj.tokenAmounts);
    }

    /**
     * A distinct Uniform Resource Identifier (URI) for a given token.
     * @param _id The token id.
     * @dev URIs are defined in RFC 3986.
     * The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
     * @return URI string
     */
    function uri(uint256 _id) external view override returns (string memory) {
        return IDelegatedERC1155Metadata(factory).metadataProvider().uri(_id);
    }

    /**
     * Query if a contract supports an interface.
     * @param  interfaceId The interfaceId to test.
     * @return supported Whether the interfaceId is supported.
     */
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165, ERC1155) returns (bool supported) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155).interfaceId
            || interfaceId == type(IERC1155Metadata).interfaceId || interfaceId == type(IERC1155FloorWrapper).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
