pragma solidity ^0.5.11;

interface INiftyswapFactory {

  /***********************************|
  |               Events              |
  |__________________________________*/

  event NewExchange(address indexed token, address indexed exchange);


  /***********************************|
  |         Public  Functions         |
  |__________________________________*/

  /**
   * @notice Creates a NiftySwap Exchange for given token contract
   * @param _token The address of the ERC-1155 token to create an NiftySwap exchange for
   */
  function createExchange(address _token) external;

  /**
   * @notice Return address of exchange for corresponding ERC-1155 token contract
   * @param _token The address of the ERC-1155 Token
   */
  function getExchange(address _token) external view returns (address);

  /**
   * @notice Return address of ERC-1155 token for corresponding NiftySwap exchange contract
   * @param _exchange The address of the ERC-1155 Token
   */
  function getToken(address _exchange) external view returns (address);
}