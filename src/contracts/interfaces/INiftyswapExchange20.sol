// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface INiftyswapExchange20 {

  /***********************************|
  |               Events              |
  |__________________________________*/

  event TokensPurchase(
    address indexed buyer,
    address indexed recipient,
    uint256[] tokensBoughtIds,
    uint256[] tokensBoughtAmounts,
    uint256[] currencySoldAmounts,
    address[] extraFeeRecipients,
    uint256[] extraFeeAmounts
  );

  event CurrencyPurchase(
    address indexed buyer,
    address indexed recipient,
    uint256[] tokensSoldIds,
    uint256[] tokensSoldAmounts,
    uint256[] currencyBoughtAmounts,
    address[] extraFeeRecipients,
    uint256[] extraFeeAmounts
  );

  event LiquidityAdded(
    address indexed provider,
    uint256[] tokenIds,
    uint256[] tokenAmounts,
    uint256[] currencyAmounts
  );

  struct LiquidityRemovedEventObj {
    uint256 currencyAmount;
    uint256 soldTokenNumerator;
    uint256 boughtCurrencyNumerator;
    uint256 totalSupply;
  }

  event LiquidityRemoved(
    address indexed provider,
    uint256[] tokenIds,
    uint256[] tokenAmounts,
    LiquidityRemovedEventObj[] details
  );

  event RoyaltyChanged(
    address indexed royaltyRecipient,
    uint256 royaltyFee
  );

  struct SellTokensObj {
    address recipient;            // Who receives the currency
    uint256 minCurrency;          // Total minimum number of currency  expected for all tokens sold
    address[] extraFeeRecipients; // Array of addresses that will receive extra fee
    uint256[] extraFeeAmounts;    // Array of amounts of currency that will be sent as extra fee
    uint256 deadline;             // Timestamp after which the tx isn't valid anymore
  }

  struct AddLiquidityObj {
    uint256[] maxCurrency; // Maximum number of currency to deposit with tokens
    uint256 deadline;      // Timestamp after which the tx isn't valid anymore
  }

  struct RemoveLiquidityObj {
    uint256[] minCurrency; // Minimum number of currency to withdraw
    uint256[] minTokens;   // Minimum number of tokens to withdraw
    uint256 deadline;      // Timestamp after which the tx isn't valid anymore
  }


  /***********************************|
  |        Purchasing Functions       |
  |__________________________________*/
  
  /**
   * @notice Convert currency tokens to Tokens _id and transfers Tokens to recipient.
   * @dev User specifies MAXIMUM inputs (_maxCurrency) and EXACT outputs.
   * @dev Assumes that all trades will be successful, or revert the whole tx
   * @dev Exceeding currency tokens sent will be refunded to recipient
   * @dev Sorting IDs is mandatory for efficient way of preventing duplicated IDs (which would lead to exploit)
   * @param _tokenIds            Array of Tokens ID that are bought
   * @param _tokensBoughtAmounts Amount of Tokens id bought for each corresponding Token id in _tokenIds
   * @param _maxCurrency         Total maximum amount of currency tokens to spend for all Token ids
   * @param _deadline            Timestamp after which this transaction will be reverted
   * @param _recipient           The address that receives output Tokens and refund
   * @param _extraFeeRecipients  Array of addresses that will receive extra fee
   * @param _extraFeeAmounts     Array of amounts of currency that will be sent as extra fee
   * @return currencySold How much currency was actually sold.
   */
  function buyTokens(
    uint256[] memory _tokenIds,
    uint256[] memory _tokensBoughtAmounts,
    uint256 _maxCurrency,
    uint256 _deadline,
    address _recipient,
    address[] memory _extraFeeRecipients,
    uint256[] memory _extraFeeAmounts
  ) external returns (uint256[] memory);

  /***********************************|
  |         Royalties Functions       |
  |__________________________________*/

  /**
   * @notice Will send the royalties that _royaltyRecipient can claim, if any 
   * @dev Anyone can call this function such that payout could be distributed 
   *      regularly instead of being claimed. 
   * @param _royaltyRecipient Address that is able to claim royalties
   */
  function sendRoyalties(address _royaltyRecipient) external;

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

  /**
   * @notice Handle which method is being called on transfer
   * @dev `_data` must be encoded as follow: abi.encode(bytes4, MethodObj)
   *   where bytes4 argument is the MethodObj object signature passed as defined
   *   in the `Signatures for onReceive control logic` section above
   * @param _from     The address which previously owned the Token
   * @param _ids      An array containing ids of each Token being transferred
   * @param _amounts  An array containing amounts of each Token being transferred
   * @param _data     Method signature and corresponding encoded arguments for method to call on *this* contract
   * @return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)")
   */
  function onERC1155BatchReceived(address, address _from, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data) external returns(bytes4);


  /***********************************|
  |         Getter Functions          |
  |__________________________________*/

  /**
   * @dev Pricing function used for converting between currency token to Tokens.
   * @param _assetBoughtAmount  Amount of Tokens being bought.
   * @param _assetSoldReserve   Amount of currency tokens in exchange reserves.
   * @param _assetBoughtReserve Amount of Tokens (output type) in exchange reserves.
   * @return Amount of currency tokens to send to Niftyswap.
   */
  function getBuyPrice(uint256 _assetBoughtAmount, uint256 _assetSoldReserve, uint256 _assetBoughtReserve) external view returns (uint256);

  /**
   * @dev Pricing function used for converting Tokens to currency token (including royalty fee)
   * @param _tokenId            Id ot token being sold
   * @param _assetBoughtAmount  Amount of Tokens being bought.
   * @param _assetSoldReserve   Amount of currency tokens in exchange reserves.
   * @param _assetBoughtReserve Amount of Tokens (output type) in exchange reserves.
   * @return price Amount of currency tokens to send to Niftyswap.
   */
  function getBuyPriceWithRoyalty(uint256 _tokenId, uint256 _assetBoughtAmount, uint256 _assetSoldReserve, uint256 _assetBoughtReserve) external view returns (uint256 price);

  /**
   * @dev Pricing function used for converting Tokens to currency token.
   * @param _assetSoldAmount    Amount of Tokens being sold.
   * @param _assetSoldReserve   Amount of Tokens in exchange reserves.
   * @param _assetBoughtReserve Amount of currency tokens in exchange reserves.
   * @return Amount of currency tokens to receive from Niftyswap.
   */
  function getSellPrice(uint256 _assetSoldAmount,uint256 _assetSoldReserve, uint256 _assetBoughtReserve) external view returns (uint256);

  /**
   * @dev Pricing function used for converting Tokens to currency token (including royalty fee)
   * @param _tokenId            Id ot token being sold
   * @param _assetSoldAmount    Amount of Tokens being sold.
   * @param _assetSoldReserve   Amount of Tokens in exchange reserves.
   * @param _assetBoughtReserve Amount of currency tokens in exchange reserves.
   * @return price Amount of currency tokens to receive from Niftyswap.
   */
  function getSellPriceWithRoyalty(uint256 _tokenId, uint256 _assetSoldAmount, uint256 _assetSoldReserve, uint256 _assetBoughtReserve) external view returns (uint256 price);

  /**
   * @notice Get amount of currency in reserve for each Token _id in _ids
   * @param _ids Array of ID sto query currency reserve of
   * @return amount of currency in reserve for each Token _id
   */
  function getCurrencyReserves(uint256[] calldata _ids) external view returns (uint256[] memory);

  /**
   * @notice Return price for `currency => Token _id` trades with an exact token amount.
   * @param _ids          Array of ID of tokens bought.
   * @param _tokensBought Amount of Tokens bought.
   * @return Amount of currency needed to buy Tokens in _ids for amounts in _tokensBought
   */
  function getPrice_currencyToToken(uint256[] calldata _ids, uint256[] calldata _tokensBought) external view returns (uint256[] memory);

  /**
   * @notice Return price for `Token _id => currency` trades with an exact token amount.
   * @param _ids        Array of IDs  token sold.
   * @param _tokensSold Array of amount of each Token sold.
   * @return Amount of currency that can be bought for Tokens in _ids for amounts in _tokensSold
   */
  function getPrice_tokenToCurrency(uint256[] calldata _ids, uint256[] calldata _tokensSold) external view returns (uint256[] memory);

  /**
   * @notice Get total supply of liquidity tokens
   * @param _ids ID of the Tokens
   * @return The total supply of each liquidity token id provided in _ids
   */
  function getTotalSupply(uint256[] calldata _ids) external view returns (uint256[] memory);

  /**
   * @return Address of Token that is sold on this exchange.
   */
  function getTokenAddress() external view returns (address);

  /**
   * @return LP fee per 1000 units
   */
  function getLPFee() external view returns (uint256);

  /**
   * @return Address of the currency contract that is used as currency
   */
  function getCurrencyInfo() external view returns (address);

  /**
   * @return Address of factory that created this exchange.
   */
  function getFactoryAddress() external view returns (address);

  /**
   * @return Global royalty fee % if not supporting ERC-2981
   */
  function getGlobalRoyaltyFee() external view returns (uint256);  

  /**
   * @return Global royalty recipient if token not supporting ERC-2981
   */
  function getGlobalRoyaltyRecipient() external view returns (address);

  /**
   * @return Get amount of currency in royalty an address can claim
   * @param _royaltyRecipient Address to check the claimable royalties
   */
  function getRoyalties(address _royaltyRecipient) external view returns (uint256);

  function getRoyaltiesNumerator(address _royaltyRecipient) external view returns (uint256);
}
