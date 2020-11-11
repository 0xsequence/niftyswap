pragma solidity 0.7.4;

interface INiftyswapFactory {

  /***********************************|
  |               Events              |
  |__________________________________*/

  event NewExchange(address indexed token, address indexed currency, uint256 indexed currencyID, address exchange);


  /***********************************|
  |         Public  Functions         |
  |__________________________________*/

  /**
   * @notice Creates a NiftySwap Exchange for given token contract
   * @param _token      The address of the ERC-1155 token contract
   * @param _currency   The address of the currency token contract
   * @param _currencyID The id of the currency token
   */
  function createExchange(address _token, address _currency, uint256 _currencyID) external;

  /**
   * @notice Return address of exchange for corresponding ERC-1155 token contract
   * @param _token      The address of the ERC-1155 token contract
   * @param _currency   The address of the currency token contract
   * @param _currencyID The id of the currency token
   */
  function tokensToExchange(address _token, address _currency, uint256 _currencyID) external view returns (address);

}