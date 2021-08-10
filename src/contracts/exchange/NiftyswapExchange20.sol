// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;
import "../interfaces/INiftyswapExchange20.sol";
import "../utils/ReentrancyGuard.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC20.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";
import "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";

/**
 * This Uniswap-like implementation supports ERC-1155 standard tokens
 * with an ERC-20 based token used as a currency instead of Ether.
 *
 * See https://github.com/0xsequence/erc20-meta-token for a generalized
 * ERC-20 => ERC-1155 token wrapper
 *
 * Liquidity tokens are also ERC-1155 tokens you can find the ERC-1155
 * implementation used here:
 *    https://github.com/horizon-games/multi-token-standard/tree/master/contracts/tokens/ERC1155
 *
 * @dev Like Uniswap, tokens with 0 decimals and low supply are susceptible to significant rounding
 *      errors when it comes to removing liquidity, possibly preventing them to be withdrawn without
 *      some collaboration between liquidity providers.
 */
contract NiftyswapExchange20 is ReentrancyGuard, ERC1155MintBurn, INiftyswapExchange20 {
  using SafeMath for uint256;

  /***********************************|
  |       Variables & Constants       |
  |__________________________________*/

  // Variables
  IERC1155 internal token;                        // address of the ERC-1155 token contract
  IERC20 internal currency;                       // address of the ERC-20 currency used for exchange
  address internal factory;                       // address for the factory that created this contract
  uint256 internal constant FEE_MULTIPLIER = 995; // Multiplier that calculates the fee (0.5%)

  // Mapping variables
  mapping(uint256 => uint256) internal totalSupplies;    // Liquidity pool token supply per Token id
  mapping(uint256 => uint256) internal currencyReserves; // currency Token reserve per Token id

  /***********************************|
  |            Constructor           |
  |__________________________________*/

  /**
   * @notice Create instance of exchange contract with respective token and currency token
   * @param _tokenAddr     The address of the ERC-1155 Token
   * @param _currencyAddr  The address of the ERC-20 currency Token
   */
  constructor(address _tokenAddr, address _currencyAddr) public {
    require(
      address(_tokenAddr) != address(0) && _currencyAddr != address(0),
      "NiftyswapExchange20#constructor:INVALID_INPUT"
    );
    factory = msg.sender;
    token = IERC1155(_tokenAddr);
    currency = IERC20(_currencyAddr);
  }

  /***********************************|
  |        Exchange Functions         |
  |__________________________________*/

  /**
   * @notice Convert currency tokens to Tokens _id and transfers Tokens to recipient.
   * @dev User specifies MAXIMUM inputs (_maxCurrency) and EXACT outputs.
   * @dev Assumes that all trades will be successful, or revert the whole tx
   * @dev Exceeding currency tokens sent will be refunded to recipient
   * @dev Sorting IDs is mandatory for efficient way of preventing duplicated IDs (which would lead to exploit)
   * @param _tokenIds             Array of Tokens ID that are bought
   * @param _tokensBoughtAmounts  Amount of Tokens id bought for each corresponding Token id in _tokenIds
   * @param _maxCurrency          Total maximum amount of currency tokens to spend for all Token ids
   * @param _deadline             Timestamp after which this transaction will be reverted
   * @param _recipient            The address that receives output Tokens and refund
   * @return currencySold How much currency was actually sold.
   */
  function _currencyToToken(
    uint256[] memory _tokenIds,
    uint256[] memory _tokensBoughtAmounts,
    uint256 _maxCurrency,
    uint256 _deadline,
    address _recipient)
    internal nonReentrant() returns (uint256[] memory currencySold)
  {
    // Input validation
    require(_deadline >= block.timestamp, "NiftyswapExchange20#_currencyToToken: DEADLINE_EXCEEDED");

    // Number of Token IDs to deposit
    uint256 nTokens = _tokenIds.length;
    uint256 totalRefundCurrency = _maxCurrency;

    // Initialize variables
    currencySold = new uint256[](nTokens); // Amount of currency tokens sold per ID
    uint256[] memory tokenReserves = new uint256[](nTokens);  // Amount of tokens in reserve for each Token id

    // Get token reserves
    tokenReserves = _getTokenReserves(_tokenIds);

    // Assumes the currency Tokens are already received by contract, but not
    // the Tokens Ids

    // Remove liquidity for each Token ID in _tokenIds
    for (uint256 i = 0; i < nTokens; i++) {
      // Store current id and amount from argument arrays
      uint256 idBought = _tokenIds[i];
      uint256 amountBought = _tokensBoughtAmounts[i];
      uint256 tokenReserve = tokenReserves[i];

      require(amountBought > 0, "NiftyswapExchange20#_currencyToToken: NULL_TOKENS_BOUGHT");

      // Load currency token and Token _id reserves
      uint256 currencyReserve = currencyReserves[idBought];

      // Get amount of currency tokens to send for purchase
      // Neither reserves amount have been changed so far in this transaction, so
      // no adjustment to the inputs is needed
      uint256 currencyAmount = getBuyPrice(amountBought, currencyReserve, tokenReserve);

      // Calculate currency token amount to refund (if any) where whatever is not used will be returned
      // Will throw if total cost exceeds _maxCurrency
      totalRefundCurrency = totalRefundCurrency.sub(currencyAmount);

      // Append Token id, Token id amount and currency token amount to tracking arrays
      currencySold[i] = currencyAmount;

      // Update individual currency reseve amount
      currencyReserves[idBought] = currencyReserve.add(currencyAmount);
    }

    // Refund currency token if any
    if (totalRefundCurrency > 0) {
      require(currency.transfer(_recipient, totalRefundCurrency), "NiftyswapExchange20#_currencyToToken: TRANSFER_FAILED");
    }

    // Send Tokens all tokens purchased
    token.safeBatchTransferFrom(address(this), _recipient, _tokenIds, _tokensBoughtAmounts, "");
    return currencySold;
  }

  /**
   * @dev Pricing function used for converting between currency token to Tokens.
   * @param _assetBoughtAmount  Amount of Tokens being bought.
   * @param _assetSoldReserve   Amount of currency tokens in exchange reserves.
   * @param _assetBoughtReserve Amount of Tokens (output type) in exchange reserves.
   * @return price Amount of currency tokens to send to Niftyswap.
   */
  function getBuyPrice(
    uint256 _assetBoughtAmount,
    uint256 _assetSoldReserve,
    uint256 _assetBoughtReserve)
    override public pure returns (uint256 price)
  {
    // Reserves must not be empty
    require(_assetSoldReserve > 0 && _assetBoughtReserve > 0, "NiftyswapExchange20#getBuyPrice: EMPTY_RESERVE");

    // Calculate price with fee
    uint256 numerator = _assetSoldReserve.mul(_assetBoughtAmount).mul(1000);
    uint256 denominator = (_assetBoughtReserve.sub(_assetBoughtAmount)).mul(FEE_MULTIPLIER);
    (price, ) = divRound(numerator, denominator);
    return price; // Will add 1 if rounding error
  }

  /**
   * @notice Convert Tokens _id to currency tokens and transfers Tokens to recipient.
   * @dev User specifies EXACT Tokens _id sold and MINIMUM currency tokens received.
   * @dev Assumes that all trades will be valid, or the whole tx will fail
   * @dev Sorting _tokenIds is mandatory for efficient way of preventing duplicated IDs (which would lead to errors)
   * @param _tokenIds          Array of Token IDs that are sold
   * @param _tokensSoldAmounts Array of Amount of Tokens sold for each id in _tokenIds.
   * @param _minCurrency       Minimum amount of currency tokens to receive
   * @param _deadline          Timestamp after which this transaction will be reverted
   * @param _recipient         The address that receives output currency tokens.
   * @return currencyBought How much currency was actually purchased.
   */
  function _tokenToCurrency(
    uint256[] memory _tokenIds,
    uint256[] memory _tokensSoldAmounts,
    uint256 _minCurrency,
    uint256 _deadline,
    address _recipient)
    internal nonReentrant() returns (uint256[] memory currencyBought)
  {
    // Number of Token IDs to deposit
    uint256 nTokens = _tokenIds.length;

    // Input validation
    require(_deadline >= block.timestamp, "NiftyswapExchange20#_tokenToCurrency: DEADLINE_EXCEEDED");

    // Initialize variables
    uint256 totalCurrency = 0; // Total amount of currency tokens to transfer
    currencyBought = new uint256[](nTokens);
    uint256[] memory tokenReserves = new uint256[](nTokens);

    // Get token reserves
    tokenReserves = _getTokenReserves(_tokenIds);

    // Assumes the Tokens ids are already received by contract, but not
    // the Tokens Ids. Will return cards not sold if invalid price.

    // Remove liquidity for each Token ID in _tokenIds
    for (uint256 i = 0; i < nTokens; i++) {
      // Store current id and amount from argument arrays
      uint256 idSold = _tokenIds[i];
      uint256 amountSold = _tokensSoldAmounts[i];
      uint256 tokenReserve = tokenReserves[i];

      // If 0 tokens send for this ID, revert
      require(amountSold > 0, "NiftyswapExchange20#_tokenToCurrency: NULL_TOKENS_SOLD");

      // Load currency token and Token _id reserves
      uint256 currencyReserve = currencyReserves[idSold];

      // Get amount of currency that will be received
      // Need to sub amountSold because tokens already added in reserve, which would bias the calculation
      // Don't need to add it for currencyReserve because the amount is added after this calculation
      uint256 currencyAmount = getSellPrice(amountSold, tokenReserve.sub(amountSold), currencyReserve);

      // Increase cost of transaction
      totalCurrency = totalCurrency.add(currencyAmount);

      // Update individual currency reseve amount
      currencyReserves[idSold] = currencyReserve.sub(currencyAmount);

      // Append Token id, Token id amount and currency token amount to tracking arrays
      currencyBought[i] = currencyAmount;
    }

    // If minCurrency is not met
    require(totalCurrency >= _minCurrency, "NiftyswapExchange20#_tokenToCurrency: INSUFFICIENT_CURRENCY_AMOUNT");

    // Transfer currency here
    require(currency.transfer(_recipient, totalCurrency), "NiftyswapExchange20#_tokenToCurrency: TRANSFER_FAILED");

    return currencyBought;
  }

  /**
   * @dev Pricing function used for converting Tokens to currency token.
   * @param _assetSoldAmount    Amount of Tokens being sold.
   * @param _assetSoldReserve   Amount of Tokens in exchange reserves.
   * @param _assetBoughtReserve Amount of currency tokens in exchange reserves.
   * @return price Amount of currency tokens to receive from Niftyswap.
   */
  function getSellPrice(
    uint256 _assetSoldAmount,
    uint256 _assetSoldReserve,
    uint256 _assetBoughtReserve)
    override public pure returns (uint256 price)
  {
    //Reserves must not be empty
    require(_assetSoldReserve > 0 && _assetBoughtReserve > 0, "NiftyswapExchange20#getSellPrice: EMPTY_RESERVE");

    // Calculate amount to receive (with fee)
    uint256 _assetSoldAmount_withFee = _assetSoldAmount.mul(FEE_MULTIPLIER);
    uint256 numerator = _assetSoldAmount_withFee.mul(_assetBoughtReserve);
    uint256 denominator = _assetSoldReserve.mul(1000).add(_assetSoldAmount_withFee);
    return numerator / denominator; //Rounding errors will favor Niftyswap, so nothing to do
  }

  /***********************************|
  |        Liquidity Functions        |
  |__________________________________*/

  /**
   * @notice Deposit less than max currency tokens && exact Tokens (token ID) at current ratio to mint liquidity pool tokens.
   * @dev min_liquidity does nothing when total liquidity pool token supply is 0.
   * @dev Assumes that sender approved this contract on the currency
   * @dev Sorting _tokenIds is mandatory for efficient way of preventing duplicated IDs (which would lead to errors)
   * @param _provider      Address that provides liquidity to the reserve
   * @param _tokenIds      Array of Token IDs where liquidity is added
   * @param _tokenAmounts  Array of amount of Tokens deposited corresponding to each ID provided in _tokenIds
   * @param _maxCurrency   Array of maximum number of tokens deposited for each ID provided in _tokenIds.
   *                       Deposits max amount if total liquidity pool token supply is 0.
   * @param _deadline      Timestamp after which this transaction will be reverted
   */
  function _addLiquidity(
    address _provider,
    uint256[] memory _tokenIds,
    uint256[] memory _tokenAmounts,
    uint256[] memory _maxCurrency,
    uint256 _deadline)
    internal nonReentrant()
  {
    // Requirements
    require(_deadline >= block.timestamp, "NiftyswapExchange20#_addLiquidity: DEADLINE_EXCEEDED");

    // Initialize variables
    uint256 nTokens = _tokenIds.length; // Number of Token IDs to deposit
    uint256 totalCurrency = 0;          // Total amount of currency tokens to transfer

    // Initialize arrays
    uint256[] memory liquiditiesToMint = new uint256[](nTokens);
    uint256[] memory currencyAmounts = new uint256[](nTokens);
    uint256[] memory tokenReserves = new uint256[](nTokens);

    // Get token reserves
    tokenReserves = _getTokenReserves(_tokenIds);

    // Assumes tokens _ids are deposited already, but not currency tokens
    // as this is calculated and executed below.

    // Loop over all Token IDs to deposit
    for (uint256 i = 0; i < nTokens; i ++) {
      // Store current id and amount from argument arrays
      uint256 tokenId = _tokenIds[i];
      uint256 amount = _tokenAmounts[i];

      // Check if input values are acceptable
      require(_maxCurrency[i] > 0, "NiftyswapExchange20#_addLiquidity: NULL_MAX_CURRENCY");
      require(amount > 0, "NiftyswapExchange20#_addLiquidity: NULL_TOKENS_AMOUNT");

      // Current total liquidity calculated in currency token
      uint256 totalLiquidity = totalSupplies[tokenId];

      // When reserve for this token already exists
      if (totalLiquidity > 0) {

        // Load currency token and Token reserve's supply of Token id
        uint256 currencyReserve = currencyReserves[tokenId]; // Amount not yet in reserve
        uint256 tokenReserve = tokenReserves[i];

        /**
        * Amount of currency tokens to send to token id reserve:
        * X/Y = dx/dy
        * dx = X*dy/Y
        * where
        *   X:  currency total liquidity
        *   Y:  Token _id total liquidity (before tokens were received)
        *   dy: Amount of token _id deposited
        *   dx: Amount of currency to deposit
        *
        * Adding .add(1) if rounding errors so to not favor users incorrectly
        */
        (uint256 currencyAmount, bool rounded) = divRound(amount.mul(currencyReserve), tokenReserve.sub(amount));
        require(_maxCurrency[i] >= currencyAmount, "NiftyswapExchange20#_addLiquidity: MAX_CURRENCY_AMOUNT_EXCEEDED");

        // Update currency reserve size for Token id before transfer
        currencyReserves[tokenId] = currencyReserve.add(currencyAmount);

        // Update totalCurrency
        totalCurrency = totalCurrency.add(currencyAmount);

        // Proportion of the liquidity pool to give to current liquidity provider
        // If rounding error occured, round down to favor previous liquidity providers
        // See https://github.com/0xsequence/niftyswap/issues/19
        liquiditiesToMint[i] = (currencyAmount.sub(rounded ? 1 : 0)).mul(totalLiquidity) / currencyReserve;
        currencyAmounts[i] = currencyAmount;

        // Mint liquidity ownership tokens and increase liquidity supply accordingly
        totalSupplies[tokenId] = totalLiquidity.add(liquiditiesToMint[i]);

      } else {
        uint256 maxCurrency = _maxCurrency[i];

        // Otherwise rounding error could end up being significant on second deposit
        require(maxCurrency >= 1000000000, "NiftyswapExchange20#_addLiquidity: INVALID_CURRENCY_AMOUNT");

        // Update currency  reserve size for Token id before transfer
        currencyReserves[tokenId] = maxCurrency;

        // Update totalCurrency
        totalCurrency = totalCurrency.add(maxCurrency);

        // Initial liquidity is amount deposited (Incorrect pricing will be arbitraged)
        // uint256 initialLiquidity = _maxCurrency;
        totalSupplies[tokenId] = maxCurrency;

        // Liquidity to mints
        liquiditiesToMint[i] = maxCurrency;
        currencyAmounts[i] = maxCurrency;
      }
    }

    // Mint liquidity pool tokens
    _batchMint(_provider, _tokenIds, liquiditiesToMint, "");

    // Transfer all currency to this contract
    require(currency.transferFrom(_provider, address(this), totalCurrency), "NiftyswapExchange20#_addLiquidity: TRANSFER_FAILED");

    // Emit event
    emit LiquidityAdded(_provider, _tokenIds, _tokenAmounts, currencyAmounts);
  }

  /**
   * @dev Burn liquidity pool tokens to withdraw currency  && Tokens at current ratio.
   * @dev Sorting _tokenIds is mandatory for efficient way of preventing duplicated IDs (which would lead to errors)
   * @param _provider         Address that removes liquidity to the reserve
   * @param _tokenIds         Array of Token IDs where liquidity is removed
   * @param _poolTokenAmounts Array of Amount of liquidity pool tokens burned for each Token id in _tokenIds.
   * @param _minCurrency      Minimum currency withdrawn for each Token id in _tokenIds.
   * @param _minTokens        Minimum Tokens id withdrawn for each Token id in _tokenIds.
   * @param _deadline         Timestamp after which this transaction will be reverted
   */
  function _removeLiquidity(
    address _provider,
    uint256[] memory _tokenIds,
    uint256[] memory _poolTokenAmounts,
    uint256[] memory _minCurrency,
    uint256[] memory _minTokens,
    uint256 _deadline)
    internal nonReentrant()
  {
    // Input validation
    require(_deadline > block.timestamp, "NiftyswapExchange20#_removeLiquidity: DEADLINE_EXCEEDED");

    // Initialize variables
    uint256 nTokens = _tokenIds.length;                        // Number of Token IDs to deposit
    uint256 totalCurrency = 0;                                 // Total amount of currency  to transfer
    uint256[] memory tokenAmounts = new uint256[](nTokens);    // Amount of Tokens to transfer for each id
    uint256[] memory currencyAmounts = new uint256[](nTokens); // Amount of currency to transfer for each id
    uint256[] memory tokenReserves = new uint256[](nTokens);

    // Get token reserves
    tokenReserves = _getTokenReserves(_tokenIds);

    // Assumes NIFTY liquidity tokens are already received by contract, but not
    // the currency nor the Tokens Ids

    // Remove liquidity for each Token ID in _tokenIds
    for (uint256 i = 0; i < nTokens; i++) {
      // Store current id and amount from argument arrays
      uint256 id = _tokenIds[i];
      uint256 amountPool = _poolTokenAmounts[i];
      uint256 tokenReserve = tokenReserves[i];

      // Load total liquidity pool token supply for Token _id
      uint256 totalLiquidity = totalSupplies[id];
      require(totalLiquidity > 0, "NiftyswapExchange20#_removeLiquidity: NULL_TOTAL_LIQUIDITY");

      // Load currency and Token reserve's supply of Token id
      uint256 currencyReserve = currencyReserves[id];

      // Calculate amount to withdraw for currency and Token _id
      uint256 currencyAmount = amountPool.mul(currencyReserve) / totalLiquidity;
      uint256 tokenAmount = amountPool.mul(tokenReserve) / totalLiquidity;

      // Verify if amounts to withdraw respect minimums specified
      require(currencyAmount >= _minCurrency[i], "NiftyswapExchange20#_removeLiquidity: INSUFFICIENT_CURRENCY_AMOUNT");
      require(tokenAmount >= _minTokens[i], "NiftyswapExchange20#_removeLiquidity: INSUFFICIENT_TOKENS");

      // Update total liquidity pool token supply of Token _id
      totalSupplies[id] = totalLiquidity.sub(amountPool);

      // Update currency reserve size for Token id
      currencyReserves[id] = currencyReserve.sub(currencyAmount);

      // Update totalCurrency and tokenAmounts
      totalCurrency = totalCurrency.add(currencyAmount);
      tokenAmounts[i] = tokenAmount;
      currencyAmounts[i] = currencyAmount;
    }

    // Burn liquidity pool tokens for offchain supplies
    _batchBurn(address(this), _tokenIds, _poolTokenAmounts);

    // Transfer total currency and all Tokens ids
    require(currency.transfer(_provider, totalCurrency), "NiftyswapExchange20#_removeLiquidity: TRANSFER_FAILED");
    token.safeBatchTransferFrom(address(this), _provider, _tokenIds, tokenAmounts, "");

    // Emit event
    emit LiquidityRemoved(_provider, _tokenIds, tokenAmounts, currencyAmounts);
  }

  /***********************************|
  |     Receiver Methods Handler      |
  |__________________________________*/

  // Method signatures for onReceive control logic

  // bytes4(keccak256(
  //   "_tokenToCurrency(uint256[],uint256[],uint256,uint256,address)"
  // ));
  bytes4 internal constant SELLTOKENS_SIG = 0xdb08ec97;

  //  bytes4(keccak256(
  //   "_addLiquidity(address,uint256[],uint256[],uint256[],uint256)"
  // ));
  bytes4 internal constant ADDLIQUIDITY_SIG = 0x82da2b73;

  // bytes4(keccak256(
  //    "_removeLiquidity(address,uint256[],uint256[],uint256[],uint256[],uint256)"
  // ));
  bytes4 internal constant REMOVELIQUIDITY_SIG = 0x5c0bf259;

  // bytes4(keccak256(
  //   "DepositTokens()"
  // ));
  bytes4 internal constant DEPOSIT_SIG = 0xc8c323f9;

  /***********************************|
  |           Buying Tokens           |
  |__________________________________*/

  /**
   * @dev Purchase tokens with currency.
   */
  function buyTokens(
    uint256[] memory _tokenIds,
    uint256[] memory _tokensBoughtAmounts,
    uint256 _maxCurrency,
    uint256 _deadline,
    address _recipient
  )
  override external returns (uint256[] memory)
  {
    require(_deadline >= block.timestamp, "NiftyswapExchange20#buyTokens: DEADLINE_EXCEEDED");
    require(_tokenIds.length > 0, "NiftyswapExchange20#buyTokens: INVALID_CURRENCY_IDS_AMOUNT");

    // Transfer the tokens for purchase
    require(currency.transferFrom(msg.sender, address(this), _maxCurrency), "NiftyswapExchange20#buyTokens: TRANSFER_FAILED");

    address recipient = _recipient == address(0x0) ? msg.sender : _recipient;

    // Execute trade and retrieve amount of currency spent
    uint256[] memory currencySold = _currencyToToken(_tokenIds, _tokensBoughtAmounts, _maxCurrency, _deadline, recipient);
    emit TokensPurchase(msg.sender, recipient, _tokenIds, _tokensBoughtAmounts, currencySold);

    return currencySold;
  }

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
  function onERC1155BatchReceived(
    address, // _operator,
    address _from,
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory _data)
    override public returns(bytes4)
  {
    // This function assumes that the ERC-1155 token contract can
    // only call `onERC1155BatchReceived()` via a valid token transfer.
    // Users must be responsible and only use this Niftyswap exchange
    // contract with ERC-1155 compliant token contracts.

    // Obtain method to call via object signature
    bytes4 functionSignature = abi.decode(_data, (bytes4));

    /***********************************|
    |           Selling Tokens          |
    |__________________________________*/

    if (functionSignature == SELLTOKENS_SIG) {

      // Tokens received need to be Token contract
      require(msg.sender == address(token), "NiftyswapExchange20#onERC1155BatchReceived: INVALID_TOKENS_TRANSFERRED");

      // Decode SellTokensObj from _data to call _tokenToCurrency()
      SellTokensObj memory obj;
      (, obj) = abi.decode(_data, (bytes4, SellTokensObj));
      address recipient = obj.recipient == address(0x0) ? _from : obj.recipient;

      // Execute trade and retrieve amount of currency received
      uint256[] memory currencyBought = _tokenToCurrency(_ids, _amounts, obj.minCurrency, obj.deadline, recipient);
      emit CurrencyPurchase(_from, recipient, _ids, _amounts, currencyBought);

    /***********************************|
    |      Adding Liquidity Tokens      |
    |__________________________________*/

    } else if (functionSignature == ADDLIQUIDITY_SIG) {
      // Only allow to receive ERC-1155 tokens from `token` contract
      require(msg.sender == address(token), "NiftyswapExchange20#onERC1155BatchReceived: INVALID_TOKEN_TRANSFERRED");

      // Decode AddLiquidityObj from _data to call _addLiquidity()
      AddLiquidityObj memory obj;
      (, obj) = abi.decode(_data, (bytes4, AddLiquidityObj));
      _addLiquidity(_from, _ids, _amounts, obj.maxCurrency, obj.deadline);

    /***********************************|
    |      Removing iquidity Tokens     |
    |__________________________________*/

    } else if (functionSignature == REMOVELIQUIDITY_SIG) {
      // Tokens received need to be NIFTY-1155 tokens
      require(msg.sender == address(this), "NiftyswapExchange20#onERC1155BatchReceived: INVALID_NIFTY_TOKENS_TRANSFERRED");

      // Decode RemoveLiquidityObj from _data to call _removeLiquidity()
      RemoveLiquidityObj memory obj;
      (, obj) = abi.decode(_data, (bytes4, RemoveLiquidityObj));
      _removeLiquidity(_from, _ids, _amounts, obj.minCurrency, obj.minTokens, obj.deadline);

    /***********************************|
    |      Deposits & Invalid Calls     |
    |__________________________________*/

    } else if (functionSignature == DEPOSIT_SIG) {
      // Do nothing for when contract is self depositing
      // This could be use to deposit currency "by accident", which would be locked
      require(msg.sender == address(currency), "NiftyswapExchange20#onERC1155BatchReceived: INVALID_TOKENS_DEPOSITED");

    } else {
      revert("NiftyswapExchange20#onERC1155BatchReceived: INVALID_METHOD");
    }

    return ERC1155_BATCH_RECEIVED_VALUE;
  }

  /**
   * @dev Will pass to onERC115Batch5Received
   */
  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes memory _data)
    override public returns(bytes4)
  {
    uint256[] memory ids = new uint256[](1);
    uint256[] memory amounts = new uint256[](1);

    ids[0] = _id;
    amounts[0] = _amount;

    require(
      ERC1155_BATCH_RECEIVED_VALUE == onERC1155BatchReceived(_operator, _from, ids, amounts, _data),
      "NiftyswapExchange20#onERC1155Received: INVALID_ONRECEIVED_MESSAGE"
    );

    return ERC1155_RECEIVED_VALUE;
  }

  /**
   * @notice Prevents receiving Ether or calls to unsuported methods
   */
  fallback () external {
    revert("NiftyswapExchange:UNSUPPORTED_METHOD");
  }

  /***********************************|
  |         Getter Functions          |
  |__________________________________*/

  /**
   * @notice Get amount of currency in reserve for each Token _id in _ids
   * @param _ids Array of ID sto query currency reserve of
   * @return amount of currency in reserve for each Token _id
   */
  function getCurrencyReserves(
    uint256[] calldata _ids)
    override external view returns (uint256[] memory)
  {
    uint256 nIds = _ids.length;
    uint256[] memory currencyReservesReturn = new uint256[](nIds);
    for (uint256 i = 0; i < nIds; i++) {
      currencyReservesReturn[i] = currencyReserves[_ids[i]];
    }
    return currencyReservesReturn;
  }

  /**
   * @notice Return price for `currency => Token _id` trades with an exact token amount.
   * @param _ids           Array of ID of tokens bought.
   * @param _tokensBought Amount of Tokens bought.
   * @return Amount of currency needed to buy Tokens in _ids for amounts in _tokensBought
   */
  function getPrice_currencyToToken(
    uint256[] calldata _ids,
    uint256[] calldata _tokensBought)
    override external view returns (uint256[] memory)
  {
    uint256 nIds = _ids.length;
    uint256[] memory prices = new uint256[](nIds);

    for (uint256 i = 0; i < nIds; i++) {
      // Load Token id reserve
      uint256 tokenReserve = token.balanceOf(address(this), _ids[i]);
      
      prices[i] = getBuyPrice(_tokensBought[i], currencyReserves[_ids[i]], tokenReserve);
    }

    // Return prices
    return prices;
  }

  /**
   * @notice Return price for `Token _id => currency` trades with an exact token amount.
   * @param _ids        Array of IDs  token sold.
   * @param _tokensSold Array of amount of each Token sold.
   * @return Amount of currency that can be bought for Tokens in _ids for amounts in _tokensSold
   */
  function getPrice_tokenToCurrency(
    uint256[] calldata _ids,
    uint256[] calldata _tokensSold)
    override external view returns (uint256[] memory)
  {
    uint256 nIds = _ids.length;
    uint256[] memory prices = new uint256[](nIds);

    for (uint256 i = 0; i < nIds; i++) {
      // Load Token id reserve
      uint256 tokenReserve = token.balanceOf(address(this), _ids[i]);
      prices[i] = getSellPrice(_tokensSold[i], tokenReserve, currencyReserves[_ids[i]]);
    }

    // Return price
    return prices;
  }

  /**
   * @return Address of Token that is sold on this exchange.
   */
  function getTokenAddress() override external view returns (address) {
    return address(token);
  }

  /**
   * @return Address of the currency contract that is used as currency
   */
  function getCurrencyInfo() override external view returns (address) {
    return (address(currency));
  }

  /**
   * @notice Get total supply of liquidity tokens
   * @param _ids ID of the Tokens
   * @return The total supply of each liquidity token id provided in _ids
   */
  function getTotalSupply(uint256[] calldata _ids)
    override external view returns (uint256[] memory)
  {
    // Number of ids
    uint256 nIds = _ids.length;

    // Variables
    uint256[] memory batchTotalSupplies = new uint256[](nIds);

    // Iterate over each owner and token ID
    for (uint256 i = 0; i < nIds; i++) {
      batchTotalSupplies[i] = totalSupplies[_ids[i]];
    }

    return batchTotalSupplies;
  }

  /**
   * @return Address of factory that created this exchange.
   */
  function getFactoryAddress() override external view returns (address) {
    return factory;
  }

  /***********************************|
  |         Utility Functions         |
  |__________________________________*/

  /**
   * @notice Divides two numbers and add 1 if there is a rounding error
   * @param a Numerator
   * @param b Denominator
   */
  function divRound(uint256 a, uint256 b) internal pure returns (uint256, bool) {
    return a % b == 0 ? (a/b, false) : ((a/b).add(1), true);
  }

  /**
   * @notice Return Token reserves for given Token ids
   * @dev Assumes that ids are sorted from lowest to highest with no duplicates.
   *      This assumption allows for checking the token reserves only once, otherwise
   *      token reserves need to be re-checked individually or would have to do more expensive
   *      duplication checks.
   * @param _tokenIds Array of IDs to query their Reserve balance.
   * @return Array of Token ids' reserves
   */
  function _getTokenReserves(
    uint256[] memory _tokenIds)
    internal view returns (uint256[] memory)
  {
    uint256 nTokens = _tokenIds.length;

    // Regular balance query if only 1 token, otherwise batch query
    if (nTokens == 1) {
      uint256[] memory tokenReserves = new uint256[](1);
      tokenReserves[0] = token.balanceOf(address(this), _tokenIds[0]);
      return tokenReserves;

    } else {
      // Lazy check preventing duplicates & build address array for query
      address[] memory thisAddressArray = new address[](nTokens);
      thisAddressArray[0] = address(this);

      for (uint256 i = 1; i < nTokens; i++) {
        require(_tokenIds[i-1] < _tokenIds[i], "NiftyswapExchange20#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS");
        thisAddressArray[i] = address(this);
      }
      return token.balanceOfBatch(thisAddressArray, _tokenIds);
    }
  }

  /**
   * @notice Indicates whether a contract implements the `ERC1155TokenReceiver` functions and so can accept ERC1155 token types.
   * @param  interfaceID The ERC-165 interface ID that is queried for support.s
   * @dev This function MUST return true if it implements the ERC1155TokenReceiver interface and ERC-165 interface.
   *      This function MUST NOT consume more thsan 5,000 gas.
   * @return Whether a given interface is supported
   */
  function supportsInterface(bytes4 interfaceID) public override pure returns (bool) {
    return interfaceID == type(IERC20).interfaceId ||
      interfaceID == type(IERC165).interfaceId || 
      interfaceID == type(IERC1155).interfaceId || 
      interfaceID == type(IERC1155TokenReceiver).interfaceId;
  }

}
