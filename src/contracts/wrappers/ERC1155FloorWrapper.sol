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

    /**
     * Creates an ERC-1155 Floor Factory.
     * @dev This contract is expected to be deployed by the ERC-1155 Floor Factory.
     */
    constructor() {
        factory = msg.sender;
    }

    /**
     * Initializes the contract with the token address.
     * @param _tokenAddr The address of the ERC-1155 token to wrap.
     * @dev This is expected to be called immediately after contract creation.
     */
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
     * @param _id The ID of the token being transferred.
     * @param _amount The amount of tokens being transferred.
     * @param _data Additional data formatted as DepositRequestObj or WithdrawRequestObj.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155Received(address, address, uint256 _id, uint256 _amount, bytes calldata _data)
        external
        returns (bytes4)
    {
        if (msg.sender == tokenAddr) {
            // Deposit
            uint256[] memory ids = new uint256[](1);
            ids[0] = _id;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = _amount;
            emit TokensDeposited(ids, amounts);
            _deposit(amounts, _data);
        } else if (msg.sender == address(this)) {
            // Withdraw
            _withdraw(_amount, _data);
        } else {
            revert InvalidERC1155Received();
        }

        return IERC1155TokenReceiver.onERC1155Received.selector;
    }

    /**
     * Accepts ERC-1155 tokens to wrap and wrapped ERC-1155 tokens to unwrap.
     * @param _ids The IDs of the tokens being transferred.
     * @param _amounts The amounts of tokens being transferred.
     * @param _data Additional data formatted as DepositRequestObj or WithdrawRequestObj.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) public returns (bytes4) {
        if (msg.sender == tokenAddr) {
            // Deposit
            emit TokensDeposited(_ids, _amounts);
            _deposit(_amounts, _data);
        } else if (msg.sender == address(this)) {
            // Withdraw
            if (_ids.length != 1) {
                revert InvalidERC1155Received();
            }
            // Either ids[0] == TOKEN_ID or amounts[0] == 0
            _withdraw(_amounts[0], _data);
        } else {
            revert InvalidERC1155Received();
        }

        return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }

    /**
     * Wrap deposited ERC-1155 tokens.
     * @param _tokenAmounts The amount of each token deposited.
     * @param _data Data received during deposit.
     */
    function _deposit(uint256[] memory _tokenAmounts, bytes calldata _data) private {
        DepositRequestObj memory obj;
        (obj) = abi.decode(_data, (DepositRequestObj));
        if (obj.recipient == address(0)) {
            // Don't allow deposits to the zero address
            revert InvalidDepositRequest();
        }

        uint256 total;
        uint256 length = _tokenAmounts.length;
        for (uint256 i; i < length;) {
            total += _tokenAmounts[i];
            unchecked {
                // Can never overflow
                i++;
            }
        }

        _mint(obj.recipient, TOKEN_ID, total, obj.data);
    }

    /**
     * Unwrap withdrawn ERC-1155 tokens.
     * @param _amount The amount of wrapped tokens received for withdraw.
     * @param _data Data received during unwrap ERC-1155 receiver request.
     */
    function _withdraw(uint256 _amount, bytes calldata _data) private {
        _burn(address(this), TOKEN_ID, _amount);

        WithdrawRequestObj memory obj;
        (obj) = abi.decode(_data, (WithdrawRequestObj));
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

        if (total != _amount) {
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
     * @param _interfaceId The interfaceId to test.
     * @return supported Whether the interfaceId is supported.
     */
    function supportsInterface(bytes4 _interfaceId) public pure override(IERC165, ERC1155) returns (bool supported) {
        return _interfaceId == type(IERC165).interfaceId || _interfaceId == type(IERC1155).interfaceId
            || _interfaceId == type(IERC1155Metadata).interfaceId || _interfaceId == type(IERC1155FloorWrapper).interfaceId
            || super.supportsInterface(_interfaceId);
    }
}
