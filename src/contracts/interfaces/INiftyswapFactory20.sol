// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.4;

interface INiftyswapFactory20 {

  /***********************************|
  |               Events              |
  |__________________________________*/

  event NewExchange(address indexed token, address indexed currency, address exchange);


  /***********************************|
  |         Public  Functions         |
  |__________________________________*/

  /**
   * @notice Creates a NiftySwap Exchange for given token contract
   * @param _token      The address of the ERC-1155 token contract
   * @param _currency   The address of the currency token contract
   */
  function createExchange(address _token, address _currency) external;

  /**
   * @notice Return address of exchange for corresponding ERC-1155 token contract
   * @param _token      The address of the ERC-1155 token contract
   * @param _currency   The address of the currency token contract
   */
  function tokensToExchange(address _token, address _currency) external view returns (address);

}
