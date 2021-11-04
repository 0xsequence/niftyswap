// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.4;
import "./NiftyswapExchange20.sol";
import "../utils/Ownable.sol";
import "../interfaces/INiftyswapFactory20.sol";

contract NiftyswapFactory20 is INiftyswapFactory20, Ownable {

  /***********************************|
  |       Events And Variables        |
  |__________________________________*/

  // tokensToExchange[erc1155_token_address][currency_address]
  mapping(address => mapping(address => mapping(uint256 => address))) public override tokensToExchange;
  mapping(address => mapping(address => address[])) internal pairExchanges;

  /**
   * @notice Will set the initial Niftyswap admin
   * @param _admin Address of the initial niftyswap admin to set as Owner
   */
  constructor(address _admin) Ownable(_admin) { }

  /***********************************|
  |             Functions             |
  |__________________________________*/
  /**
   * @notice Creates a NiftySwap Exchange for given token contract
   * @param _token    The address of the ERC-1155 token contract
   * @param _currency The address of the ERC-20 token contract
   * @param _instance Instance # that allows to deploy new instances of an exchange.
   *                  This is mainly meant to be used for tokens that change their ERC-2981 support.
   */
  function createExchange(address _token, address _currency, uint256 _instance) public override {
    require(tokensToExchange[_token][_currency][_instance] == address(0x0), "NiftyswapFactory20#createExchange: EXCHANGE_ALREADY_CREATED");

    // Create new exchange contract
    NiftyswapExchange20 exchange = new NiftyswapExchange20(_token, _currency);

    // Store exchange and token addresses
    tokensToExchange[_token][_currency][_instance] = address(exchange);
    pairExchanges[_token][_currency].push(address(exchange));

    // Emit event
    emit NewExchange(_token, _currency, _instance, address(exchange));
  }

  /**
   * @notice Returns array of exchange instances for a given pair
   * @param _token    The address of the ERC-1155 token contract
   * @param _currency The address of the ERC-20 token contract
   */
  function getPairExchanges(address _token, address _currency) public override view returns (address[] memory) {
    return pairExchanges[_token][_currency];
  }

}
