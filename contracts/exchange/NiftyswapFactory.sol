pragma solidity ^0.5.16;
import "./NiftyswapExchange.sol";


contract NiftyswapFactory {

  /***********************************|
  |       Events And Variables        |
  |__________________________________*/

  // tokensToExchange[erc1155_token_address][base_currency_address][base_currency_token_id]
  mapping(address => mapping(address => mapping(uint256 => address))) public tokensToExchange;
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
    require(tokensToExchange[_token][_baseTokenAddr][_baseTokenID] == address(0x0), "NiftyswapFactory#createExchange: EXCHANGE_ALREADY_CREATED");

    // Create new exchange contract
    NiftyswapExchange exchange = new NiftyswapExchange(_token, _baseTokenAddr, _baseTokenID);

    // Store exchange and token addresses
    tokensToExchange[_token][_baseTokenAddr][_baseTokenID] = address(exchange);

    // Emit event
    emit NewExchange(_token, _baseTokenAddr, _baseTokenID, address(exchange));
  }

}
