pragma solidity ^0.5.10;

interface INiftyswapExchange {

  /***********************************|
  |               Events              |
  |__________________________________*/

  event TokenPurchase(address indexed buyer, uint256 indexed baseTokeSold, uint256 indexed tokensBought);
  event BaseTokenPurchase(address indexed buyer, uint256 indexed tokensSold, uint256 indexed baseTokensBought);
  event AddLiquidity(address indexed provider, uint256 indexed baseTokenAmount, uint256 indexed tokenAmount);
  event RemoveLiquidity(address indexed provider, uint256 indexed baseTokenAmount, uint256 indexed tokenAmount);


  /***********************************|
  |        OnReceive Functions        |
  |__________________________________*/

  /**
   * @notice Handle which method is being called on Token transfer
   * @dev `_data` must be encoded as follow: abi.encode(bytes4, MethodObj)
   *   where bytes4 argument is the MethodObj object signature passed as defined
   *   in the `Signatures for onReceive control logic` section above
   * @param _operator The address which called the `safeTransferFrom` function
   * @param _from     The address which previously owned the token
   * @param _id       The id of the token being transferred
   * @param _amount   The amount of tokens being transferred
   * @param _data     Method signature and corresponding encoded arguments for method to call on *this* contract
   * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
   */
  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data) external returns(bytes4);


  /***********************************|
  |         Getter Functions          |
  |__________________________________*/

  /**
   * @dev Pricing function for converting between Base Tokens && Tokens.
   * @param _assetBoughtAmount  Amount of Base Tokens or Tokens being bought.
   * @param _assetSoldReserve   Amount of Base Tokens or Tokens (input type) in exchange reserves.
   * @param _assetBoughtReserve Amount of Base Tokens or Tokens (output type) in exchange reserves.
   * @return Amount of Base Tokens or Tokens sold.
   */
  function getBuyPrice(uint256 _assetBoughtAmount, uint256 _assetSoldReserve, uint256 _assetBoughtReserve) external view returns (uint256);

  /**
   * @dev Pricing function for converting between Base Tokens && Tokens.
   * @param _assetSoldAmount    Amount of Base Tokens or Tokens being sold.
   * @param _assetSoldReserve   Amount of Base Tokens or Tokens (output type) in exchange reserves.
   * @param _assetBoughtReserve Amount of Base Tokens or Tokens (input type) in exchange reserves.
   * @return Amount of Base Tokens or Tokens to receive from Uniswap.
   */
  function getSellPrice(uint256 _assetSoldAmount,uint256 _assetSoldReserve, uint256 _assetBoughtReserve) external view returns (uint256);

  /**
   * @notice Return price for `Base Token => Token _id` trades with an exact token amount.
   * @param _id          ID of token bought.
   * @param _tokensBought Amount of Tokens bought.
   * @return Amount of Base Tokens needed to buy Tokens.
   */
  function getPrice_baseToToken(uint256 _id, uint256 _tokensBought) external view returns (uint256 baseTokenAmountSold);

  /**
   * @notice Return price for `Token _id => Base Token` trades with an exact token amount.
   * @param _id        ID of token bought.
   * @param _tokensSold Amount of Tokens sold.
   * @return Amount of Base Tokens that can be bought with Tokens.
   */
  function getPrice_tokenToBase(uint256 _id, uint256 _tokensSold) external view returns (uint256 baseTokenAmountBought);

  /**
   * @return Address of Token that is sold on this exchange.
   */
  function tokenAddress() external view returns (address);

  /**
   * @return Address of factory that created this exchange.
   */
  function factoryAddress() external view returns (address);

}