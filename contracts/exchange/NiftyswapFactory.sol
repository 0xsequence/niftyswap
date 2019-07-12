pragma solidity ^0.5.10;
import "./NiftyswapExchange.sol";


contract NiftyswapFactory {

  /***********************************|
  |       Events And Variables        |
  |__________________________________*/

  IERC1155 baseToken;         // Address of the ERC-1155 base token traded on this contract
  uint256 public baseTokenID; // ID of base token in ERC-1155 base contract
  uint256 public tokenCount;  // Number of ERC-1155 exchange contract created
  mapping (address => address) internal tokenToExchange;
  mapping (address => address) internal exchangeToToken;

  event NewExchange(address indexed token, address indexed exchange);


  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Create the NiftySwap Factory
   * @param _baseTokenAddr The address of the ERC-1155 Base Token
   * @param _baseTokenID   The ID of the ERC-1155 Base Token
   */
  constructor(address _baseTokenAddr, uint256 _baseTokenID) public {
    require(
      address(_baseTokenAddr) != address(0),
      "NiftyswapFactory#constructor: INVALID_BASE_TOKEN_ADDRESS"
    );
    baseToken = IERC1155(_baseTokenAddr);
    baseTokenID = _baseTokenID;
  }

  /**
   * @notice Creates a NiftySwap Exchange for given token contract
   * @param _token The address of the ERC-1155 token to create an NiftySwap exchange for
   */
  function createExchange(address _token) public {
    require(_token != address(0), "NiftyswapFactory#createExchange: INVALID_TOKEN");
    require(tokenToExchange[_token] == address(0), "NiftyswapFactory#createExchange: TOKEN_ALREADY_INITIALIZED");

    // Create new exchange contract
    NiftyswapExchange exchange = new NiftyswapExchange(_token, address(baseToken), baseTokenID);

    // Store exchange and token addresses
    tokenToExchange[_token] = address(exchange);
    exchangeToToken[address(exchange)] = _token;

    // Increment amount of token exchange created
    uint256 tokenId = tokenCount + 1;
    tokenCount = tokenId;

    emit NewExchange(_token, address(exchange));
  }

  /***********************************|
  |         Getter Functions          |
  |__________________________________*/

  /**
   * @notice Return address of exchange for corresponding ERC-1155 token contract
   * @param _token The address of the ERC-1155 Token
   */
  function getExchange(address _token) public view returns (address) {
    return tokenToExchange[_token];
  }

  /**
   * @notice Return address of ERC-1155 token for corresponding NiftySwap exchange contract
   * @param _exchange The address of the ERC-1155 Token
   */
  function getToken(address _exchange) public view returns (address) {
    return exchangeToToken[_exchange];
  }

}
