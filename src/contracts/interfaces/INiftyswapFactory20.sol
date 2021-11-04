// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.4;

interface INiftyswapFactory20 {

  /***********************************|
  |               Events              |
  |__________________________________*/

  event NewExchange(address indexed token, address indexed currency, uint256 indexed salt, address exchange);


  /***********************************|
  |         Public  Functions         |
  |__________________________________*/

  /**
   * @notice Creates a NiftySwap Exchange for given token contract
   * @param _token      The address of the ERC-1155 token contract
   * @param _currency   The address of the currency token contract
   * @param _instance Instance # that allows to deploy new instances of an exchange.
   *                  This is mainly meant to be used for tokens that change their ERC-2981 support.
   */
  function createExchange(address _token, address _currency, uint256 _instance) external;

  /**
   * @notice Return address of exchange for corresponding ERC-1155 token contract
   * @param _token      The address of the ERC-1155 token contract
   * @param _currency   The address of the currency token contract
   * @param _instance Instance # that allows to deploy new instances of an exchange.
   *                  This is mainly meant to be used for tokens that change their ERC-2981 support.
   */
  function tokensToExchange(address _token, address _currency, uint256 _instance) external view returns (address);

  /**
   * @notice Returns array of exchange instances for a given pair
   * @param _token    The address of the ERC-1155 token contract
   * @param _currency The address of the ERC-20 token contract
   */
  function getPairExchanges(address _token, address _currency) external view returns (address[] memory);
}
