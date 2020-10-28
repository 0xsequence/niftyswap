pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "../interfaces/INiftyswapExchange.sol";
import "multi-token-standard/contracts/interfaces/IERC20.sol";
import "multi-token-standard/contracts/interfaces/IERC1155.sol";
import "multi-token-standard/contracts/interfaces/IERC1155TokenReceiver.sol";
import "erc20-meta-token/contracts/interfaces/IMetaERC20Wrapper.sol";

/**
 * @notice Will allow users to wrap their  ERC-20 into ERC-1155 tokens
 *         and pass their order to niftyswap. All funds will be returned
 *         to original owner and this contact should never hold any funds
 *         outside of a given wrap transaction.
 * @dev Hardcoding addresses for simplicity, easy to generalize if arguments
 *      are passed in functions, but adds a bit of complexity.
 */
contract WrapAndNiftyswap {

  IMetaERC20Wrapper immutable public tokenWrapper; // ERC-20 to ERC-1155 token wrapper contract
  address immutable public exchange;    // Niftyswap exchange to use
  address immutable public erc20;                   // ERC-20 used in niftyswap exchange
  address immutable public erc1155;               // ERC-1155 used in niftyswap exchange

  uint256 immutable internal wrappedTokenID; // ID of the wrapped token
  bool internal isInNiftyswap;               // Whether niftyswap is being called

  /**
   * @notice Registers contract addresses
   */
  constructor(
    address payable _tokenWrapper,
    address _exchange,
    address _erc20,
    address _erc1155
  ) public {
    require(
      _tokenWrapper != address(0x0) &&
      _exchange != address(0x0) &&
      _erc20 != address(0x0) &&
      _erc1155 != address(0x0),
      "INVALID CONSTRUCTOR ARGUMENT"
    );

    tokenWrapper = IMetaERC20Wrapper(_tokenWrapper);
    exchange = _exchange;
    erc20 = _erc20;
    erc1155 = _erc1155;

    // Approve wrapper contract for ERC-20
    // NOTE: This could potentially fail in some extreme usage as it's only
    // set once, but can easily redeploy this contract if that's the case.
    IERC20(_erc20).approve(_tokenWrapper, 2**256-1);

    // Store wrapped token ID
    wrappedTokenID = IMetaERC20Wrapper(_tokenWrapper).getTokenID(_erc20);
  }

  /**
   * @notice Wrap ERC-20 to ERC-1155 and swap them
   * @dev User must approve this contract for ERC-20 first
   * @param _maxAmount       Maximum amount of ERC-20 user wants to spend
   * @param _recipient       Address where to send tokens
   * @param _niftyswapOrder  Encoded Niftyswap order passed in data field of safeTransferFrom()
   */
  function wrapAndSwap(
    uint256 _maxAmount,
    address _recipient,
    bytes calldata _niftyswapOrder
  ) external
  {
    // Decode niftyswap order
    INiftyswapExchange.BuyTokensObj memory obj;
    (, obj) = abi.decode(_niftyswapOrder, (bytes4, INiftyswapExchange.BuyTokensObj));
    
    // Force the recipient to not be set, otherwise wrapped token refunded will be 
    // sent to the user and we won't be able to unwrap it.
    require(
      obj.recipient == address(0x0) || obj.recipient == address(this), 
      "WrapAndNiftyswap#wrapAndSwap: ORDER RECIPIENT MUST BE THIS CONTRACT"
    );

    // Pull ERC-20 amount specified in order
    IERC20(erc20).transferFrom(msg.sender, address(this), _maxAmount);

    // Wrap ERC-20s
    tokenWrapper.deposit(erc20, address(this), _maxAmount);

    // Swap on Niftyswap
    isInNiftyswap = true;
    tokenWrapper.safeTransferFrom(address(this), exchange, wrappedTokenID, _maxAmount, _niftyswapOrder);
    isInNiftyswap = false;

    // Unwrap ERC-20 and send to receiver, if any received
    uint256 wrapped_token_amount = tokenWrapper.balanceOf(address(this), wrappedTokenID);
    if (wrapped_token_amount > 0) {
      tokenWrapper.withdraw(erc20, payable(_recipient), wrapped_token_amount);
    }

    // Transfer tokens purchased
    IERC1155(erc1155).safeBatchTransferFrom(address(this), _recipient, obj.tokensBoughtIDs, obj.tokensBoughtAmounts, "");
  }

  /**
   * @notice Accepts all ERC-1155
   * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
   */
  function onERC1155Received(address, address, uint256, uint256, bytes calldata)
    external returns(bytes4)
  {
    return IERC1155TokenReceiver.onERC1155Received.selector;
  }

  /**
   * @notice Accepts all ERC-1155
   * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
   */
  function onERC1155BatchReceived(
    address, 
    address _from, 
    uint256[] calldata _ids, 
    uint256[] calldata _amounts, 
    bytes calldata _niftyswapOrder
  )
    external returns(bytes4)
  { 
    // If coming from niftyswap or wrapped token, ignore
    if (isInNiftyswap || msg.sender == address(tokenWrapper)){
      return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
    } else if (msg.sender != erc1155) {
      revert("WrapAndNiftyswap#onERC1155BatchReceived: INVALID_ERC1155_RECEIVED");
    }

    // Decode transfer data
    INiftyswapExchange.SellTokensObj memory obj;
    (,obj) = abi.decode(_niftyswapOrder, (bytes4, INiftyswapExchange.SellTokensObj));

    require(
      obj.recipient == address(0x0) || obj.recipient == address(this), 
      "WrapAndNiftyswap#onERC1155BatchReceived: ORDER RECIPIENT MUST BE THIS CONTRACT"
    );

    // Swap on Niftyswap
    isInNiftyswap = true;
    IERC1155(msg.sender).safeBatchTransferFrom(address(this), exchange, _ids, _amounts, _niftyswapOrder);
    isInNiftyswap = false;

    // Send to recipient the unwrapped ERC-20, if any
    uint256 wrapped_token_amount = tokenWrapper.balanceOf(address(this), wrappedTokenID);
    if (wrapped_token_amount > 0) {
      tokenWrapper.withdraw(erc20, payable(_from), wrapped_token_amount);
    }

    return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
  }
}
