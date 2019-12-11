pragma solidity ^0.5.14;
import "./NiftyswapExchange.sol";


contract NiftyswapFactory {

  /***********************************|
  |       Events And Variables        |
  |__________________________________*/

  mapping (address => address) internal tokenToExchange;
  event NewExchange(address indexed token, address indexed baseToken, uint256 baseTokenID, address indexed exchange);

  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Creates a NiftySwap Exchange for given token contract
   * @dev Possible to create exchanges with fake base currency, blocking proper exchange creation
   * @param _token         The address of the ERC-1155 token to create an NiftySwap exchange for
   * @param _baseTokenAddr The address of the ERC-1155 Base Token
   * @param _baseTokenID   The ID of the ERC-1155 Base Token (must be divisible, ideally > 12 decimals)
   */
  function createExchange(address _token, address _baseTokenAddr, uint256 _baseTokenID) public {
    // require(_token != address(0x0), "NiftyswapFactory#createExchange: INVALID_TOKEN_ADDRESS");
    // require(_baseTokenAddr != address(0x0), "NiftyswapFactory#createExchange: INVALID_BASE_TOKEN_ADDRESS");
    // ^^^ Checked in NiftyswapExchange.sol constructor
    require(tokenToExchange[_token] == address(0x0), "NiftyswapFactory#createExchange: EXCHANGE_ALREADY_CREATED");

    // Create new exchange contract
    NiftyswapExchange exchange = new NiftyswapExchange(_token, _baseTokenAddr, _baseTokenID);

    // Store exchange and token addresses
    tokenToExchange[_token] = address(exchange);

    // Emit event
    emit NewExchange(_token, _baseTokenAddr, _baseTokenID, address(exchange));
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
}
