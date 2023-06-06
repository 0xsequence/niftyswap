// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "../interfaces/IERC1155Metadata.sol";
import {IDelegatedERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";
import {ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155.sol";
import {ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {WrapperErrors} from "../utils/WrapperErrors.sol";

import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721FloorWrapper, IERC1155TokenReceiver, IERC721Receiver} from "../interfaces/IERC721FloorWrapper.sol";

/**
 * @notice Allows users to wrap any amount of a ERC-721 token with a 1:1 ratio.
 * Therefore each ERC-721 within a collection can be treated as if fungible.
 */
contract ERC721FloorWrapper is IERC721FloorWrapper, ERC1155MintBurn, IERC1155Metadata, WrapperErrors {
    IERC721 public token;
    address internal immutable factory;
    // This contract only supports a single token id
    uint256 public constant TOKEN_ID = 0;

    /**
     * Creates an ERC-721 Floor Factory.
     * @dev This contract is expected to be deployed by the ERC-721 Floor Factory.
     */
    constructor() {
        factory = msg.sender;
    }

    /**
     * Initializes the contract with the token address.
     * @param _tokenAddr The address of the ERC-721 token to wrap.
     * @dev This is expected to be called immediately after contract creation.
     */
    function initialize(address _tokenAddr) external {
        if (msg.sender != factory || address(token) != address(0)) {
            revert InvalidInitialization();
        }
        token = IERC721(_tokenAddr);
    }

    /**
     * Prevent invalid method calls.
     */
    fallback() external {
        revert UnsupportedMethod();
    }

    //
    // Deposit
    //

    /**
     * Accepts ERC-721 tokens to wrap.
     * @param _tokenId The ID of the token being transferred.
     * @param _data Additional data formatted as DepositRequestObj.
     * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     * @notice This is the preferred method for wrapping a single token.
     */
    function onERC721Received(address, address, uint256 _tokenId, bytes calldata _data) external returns (bytes4) {
        if (msg.sender != address(token)) {
            revert InvalidERC721Received();
        }
        DepositRequestObj memory obj;
        (obj) = abi.decode(_data, (DepositRequestObj));
        if (obj.recipient == address(0)) {
            // Don't allow deposits to the zero address
            revert InvalidWithdrawRequest();
        }

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        emit TokensDeposited(tokenIds);

        _mint(obj.recipient, TOKEN_ID, 1, obj.data);

        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * Deposit and wrap ERC-721 tokens.
     * @param _tokenIds The ERC-721 token ids to deposit.
     * @param _recipient The recipient of the wrapped tokens.
     * @param _data Data to pass to ERC-1155 receiver.
     * @notice Users must first approve this contract address on the ERC-721 contract.
     * @notice This function can wrap multiple ERC-721 tokens at once.
     */
    function deposit(uint256[] calldata _tokenIds, address _recipient, bytes calldata _data) external {
        if (_recipient == address(0)) {
            revert InvalidDepositRequest();
        }

        uint256 length = _tokenIds.length;
        for (uint256 i; i < length;) {
            // Intentionally unsafe transfer
            token.transferFrom(msg.sender, address(this), _tokenIds[i]);
            unchecked {
                // Can never overflow
                i++;
            }
        }
        emit TokensDeposited(_tokenIds);
        _mint(_recipient, TOKEN_ID, length, _data);
    }

    //
    // Withdraw
    //

    /**
     * Accepts wrapped ERC-1155 tokens to unwrap.
     * @param _amount The amount of tokens being transferred.
     * @param _data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)`
     */
    function onERC1155Received(address, address, uint256, uint256 _amount, bytes calldata _data)
        external
        returns (bytes4)
    {
        if (msg.sender != address(this)) {
            revert InvalidERC1155Received();
        }
        _withdraw(_amount, _data);

        return IERC1155TokenReceiver.onERC1155Received.selector;
    }

    /**
     * Accepts wrapped ERC-1155 tokens to unwrap.
     * @param _ids The IDs of the tokens being transferred.
     * @param _amounts The amounts of tokens being transferred.
     * @param _data Additional data formatted as WithdrawRequestObj.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) public returns (bytes4) {
        if (msg.sender != address(this)) {
            // Only accept tokens from this contract
            revert InvalidERC1155Received();
        }

        assert(_ids.length == 1); // Always true, see transfer override
        _withdraw(_amounts[0], _data);

        return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }

    /**
     * Unwrap and withdraw ERC-721 tokens.
     * @param _amount The amount of ERC-1155 tokens recieved.
     * @param _data Additional data formatted as WithdrawRequestObj.
     */
    function _withdraw(uint256 _amount, bytes calldata _data) private {
        WithdrawRequestObj memory obj;
        (obj) = abi.decode(_data, (WithdrawRequestObj));
        if (obj.recipient == address(0)) {
            // Don't allow deposits to the zero address
            revert InvalidWithdrawRequest();
        }

        uint256 length = obj.tokenIds.length;
        if (_amount != length) {
            // The amount of tokens received must match the amount of tokens being withdrawn
            revert InvalidWithdrawRequest();
        }

        _burn(msg.sender, TOKEN_ID, length);
        emit TokensWithdrawn(obj.tokenIds);
        for (uint256 i; i < length;) {
            token.safeTransferFrom(address(this), obj.recipient, obj.tokenIds[i], obj.data);
            unchecked {
                // Can never overflow
                i++;
            }
        }
    }

    //
    // Transfer overrides
    //

    /**
     * Transfers amount amount of an _id from the _from address to the _to address specified
     * @param _from Source address
     * @param _to Target address
     * @param _id ID of the token type
     * @param _amount Transfered amount
     * @param _data Additional data with no specified format, sent in call to `_to`
     */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data)
        public
        override(ERC1155, IERC1155)
    {
        if (_amount == 0) {
            revert InvalidTransferRequest();
        }

        super.safeTransferFrom(_from, _to, _id, _amount, _data);
    }

    /**
     * Send multiple types of Tokens from the _from address to the _to address (with safety call)
     * @param _from Source addresses
     * @param _to Target addresses
     * @param _ids IDs of each token type
     * @param _amounts Transfer amounts per token type
     * @param _data Additional data with no specified format, sent in call to `_to`
     * @dev As this contract only supports a single token id, this function requires a single transfer.
     * @dev Prefer using `safeTransferFrom` over this function.
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public override(ERC1155, IERC1155) {
        if (_ids.length != 1 || _ids[0] != TOKEN_ID || _amounts.length != 1 || _amounts[0] == 0) {
            revert InvalidTransferRequest();
        }

        super.safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }

    //
    // Views
    //

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
    function supportsInterface(bytes4 _interfaceId) public view override(IERC165, ERC1155) returns (bool supported) {
        return _interfaceId == type(IERC165).interfaceId || _interfaceId == type(IERC1155).interfaceId
            || _interfaceId == type(IERC1155Metadata).interfaceId || super.supportsInterface(_interfaceId);
    }
}
