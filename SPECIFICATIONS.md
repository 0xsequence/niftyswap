# Niftyswap Specification

\* Certain sections of this document were taken directly from the [Uniswap](<https://hackmd.io/@477aQ9OrQTCbVR3fq1Qzxg/HJ9jLsfTz?type=view>) documentation.

# Table of Content

# Overview

Niftyswap is a fork of [Uniswap](<https://hackmd.io/@477aQ9OrQTCbVR3fq1Qzxg/HJ9jLsfTz?type=view>), a protocol for automated token exchange on Ethereum. While Uniswap is for trading [ERC-20](<https://eips.ethereum.org/EIPS/eip-20>) tokens, Niftyswap is a protocol for [ERC-1155](<https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md>) tokens. Both are designed to favor ease of use and provide guaranteed access to liquidity on-chain. 

Most exchanges maintain an order book and facilitate matches between buyers and sellers. Niftyswap smart contracts hold liquidity reserves of various tokens, and trades are executed directly against these reserves. Prices are set automatically using the [constant product](https://ethresear.ch/t/improving-front-running-resistance-of-x-y-k-market-makers/1281)  $x*y = K$ market maker mechanism, which keeps overall reserves in relative equilibrium. Reserves are pooled between a network of liquidity providers who supply the system with tokens in exchange for a proportional share of transaction fees. 

An important feature of Nitfyswap is the utilization of a factory/registry contract that deploys a separate exchange contract for each ERC-1155 token contract. These exchange contracts each hold independent reserves of a single fungible ERC-1155 base currency and their associated ERC-1155 token id. This allows trades between the [Base Currency](???) and the ERC-1155 tokens based on the relative supplies. 

This document outlines the core mechanics and technical details for Niftyswap. 

# Contracts

### NiftyswapExchange.sol

This contract is responsible for permitting the exchange between a single base currency and all tokens in a given ERC-1155 token contract. For each token id $i$, the NiftyswapExchance contract holds a reserve of base currency and a reserve of token id $i$, which are used to calculate the price of that token id $i$ denominated in the base currency. 

### NiftyswapFactory.sol

This contract is used to deploy a new NiftyswapExchange.sol contract for ERC-1155 contracts without one yet. It will keep a mapping of each ERC-1155 token contract address with their corresponding NiftyswapExchange.sol contract address.

# Contract Interactions

*All methods should be free of arithmetic overflows and underflows.*

Methods for exchanging tokens and managing reserves liquidity are all called internally via the ERC-1155 `onERC1155BatchReceived()` method. The four methods that can be called via `onERC1155BatchReceived()` should be safe against re-entrancy attacks.

```solidity
/**
 * @notice Handle which method is being called on transfer
 * @dev `_data` must be encoded as follow: abi.encode(bytes4, MethodObj)
 *   where bytes4 argument is the MethodObj signature passed as defined
 *   in the `Signatures for onReceive control logic` section above
 * @param _operator The address which called safeBachTransferFrom()
 * @param _from     The address which previously owned the Token
 * @param _ids      An array containing Token ids being transferred
 * @param _amounts  An array containing token amounts being transferred
 * @param _data     Method signature and corresponding encoded arguments 
 * @return bytes4(keccak256(
 *  "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
 * ))
 */
function onERC1155BatchReceived(
  address _operator,
  address _from,
  uint256[] memory _ids,
  uint256[] memory _amounts,
  bytes memory _data)
  public returns(bytes4);
```

The first 4 bytes of the `_data` argument indicate which of the four main [NiftyswapExchange.sol](???) methods to call. How to build and encode the `_data` payload for the respective methods is explained in the [???](???) section. 

## Exchanging Tokens

In [NiftyswapExchange.sol](???), there are two methods for exchanging tokens:

```Solidity
/**
 * @notice Convert Base Tokens to Tokens _id and transfers Tokens to recipient.
 * @dev User specifies MAXIMUM inputs (_maxBaseTokens) and EXACT outputs.
 * @dev Assumes that all trades will be successful, or revert the whole tx
 * @dev Sorting IDs can lead to more efficient trades with some ERC-1155 implementations
 * @param _tokenIds             Array of Tokens ID that are bought
 * @param _tokensBoughtAmounts  Amount of Tokens id bought for each id in _tokenIds
 * @param _maxBaseTokens        Total maximum amount of base tokens to spend for whole trade
 * @param _deadline             Block # after which this tx can no longer be executed.
 * @param _recipient            The address that receives output Tokens.
 */
function _baseToToken(
  uint256[] memory _tokenIds,
  uint256[] memory _tokensBoughtAmounts,
  uint256 _maxBaseTokens,
  uint256 _deadline,
  address _recipient)
  internal nonReentrant();

/**
 * @notice Convert Tokens _id to Base Tokens and transfers Tokens to recipient.
 * @dev User specifies EXACT Tokens _id sold and MINIMUM Base Tokens received.
 * @dev Assumes that all trades will be valid, or the whole tx will fail
 * @param _tokenIds          Array of Token IDs that are sold
 * @param _tokensSoldAmounts Array of Amount of Tokens sold for each id in _tokenIds.
 * @param _minBaseTokens     Minimum amount of Base Tokens to receive
 * @param _deadline          Block # after which this tx can no longer be executed.
 * @param _recipient         The address that receives output Base Tokens.
 */
function _tokenToBase(
  uint256[] memory _tokenIds,
  uint256[] memory _tokensSoldAmounts,
  uint256 _minBaseTokens,
  uint256 _deadline,
  address _recipient)
  internal nonReentrant();
```

## Managing Reserves Liquidity

In [NiftyswapExchange.sol](???), there are two methods for managing token reserves supplies:

```solidity
/**
 * @notice Deposit max Base Tokens & exact Tokens at current ratio to get share tokens.
 * @dev min_liquidity does nothing when total NIFTY liquidity token supply is 0.
 * @dev Assumes that sender approved this contract on the baseToken
 * @param _provider      Address that provides liquidity to the reserve
 * @param _tokenIds      Array of Token IDs where liquidity is added
 * @param _tokenAmounts  Array of amount of Tokens deposited for ids in _tokenIds
 * @param _maxBaseTokens Array of maximum number of tokens deposited for ids in _tokenIds.
 *                       Deposits max amount if total NIFTY supply is 0.
 * @param _deadline      Block # after which this transaction can no longer be executed.
 */
function _addLiquidity(
  address _provider,
  uint256[] memory _tokenIds,
  uint256[] memory _tokenAmounts,
  uint256[] memory _maxBaseTokens,
  uint256 _deadline)
  internal nonReentrant();
  
/**
 * @dev Burn NIFTY liquidity tokens to withdraw Base Tokens && Tokens at current ratio.
 * @param _provider          Address that removes liquidity to the reserve
 * @param _tokenIds          Array of Token IDs where liquidity is removed
 * @param _NIFTYtokenAmounts Array of Amount Niftyswap shared burned for ids in _tokenIds.
 * @param _minBaseTokens     Minimum Tase Tokens withdrawn for each Token id in _tokenIds.
 * @param _minTokens         Minimum Tokens id withdrawn for each Token id in _tokenIds.
 * @param _deadline          Block # after which this transaction can no longer be executed.
 */
function _removeLiquidity(
  address _provider,
  uint256[] memory _tokenIds,
  uint256[] memory _NIFTYtokenAmounts,
  uint256[] memory _minBaseTokens,
  uint256[] memory _minTokens,
  uint256 _deadline) 
  internal nonReentrant();
```

# Price Calculations

In Niftyswap, like Uniswap, the price of an asset is a function of a base currency reserve and the corresponding token reserve. Indeed, all methods in Niftyswap enforce that the the following equality remains true: 

​												$BaseReserve_i * TokenReserve_i = K$

where $BaseReserve_i$ is the base currency reserve size for the corresponding token id $i$, $TokenReserve_i$ is the reserve size of the ERC-1155 token id $i$ and $K$ is an arbitrary constant. 

**Ignoring the [Liquidity Fee](???)**, purchasing some tokens $i$ with the base currency (or vice versa) should increase the $BaseReserve_i$ and decrease the $TokenReserve_i$ (or vice versa) such that 

​												$BaseReserve_i * TokenReserve_i == K$. 

Determining the cost of *purchasing* $\Delta{}TokenReserve_i $ tokens $i$ therefore depends on the quantity purchased, such that 

​								$\Delta{}BaseReserve_i = \frac{K}{TokenReserve_i - \Delta{}TokenReserve_i} - BaseReserve_i$

where $\Delta{}BaseReserve_i$ is the amount of base currency assets that must be sent cover the cost of the $\Delta{}TokenReserve_i $ purchased. Inversely, determining the revenue from *selling* $\Delta{}TokenReserve_i $ tokens $i$ can be done with

​								$\Delta{}BaseReserve_i = BaseReserve_i - \frac{K}{TokenReserve_i + \Delta{}TokenReserve_i}$

where $\Delta{}BaseReserve_i$ is the amount of base currency that a user would receive. 

#Liquidity Fee

A liquidity provider fee of **0.5%** paid in the base currency is added to every trade, increasing the corresponding $BaseReserve_i$. Compared to the 0.3% fee chosen by Uniswap, the 0.5% fee was chosen to ensure that token reserves are deep, which ultimately provides a better experience for users (less slippage, better price discovery and lower risk of transactions failing). This value could change for Niftyswap V2. 

While the $BaseReserve_i$ / $TokenReserve_i$ ratio is constantly shifting, fees makes sure that the total combined reserve size increases with every trade. This functions as a payout to liquidity providers that is collected when they burn their liquidity pool tokens to withdraw their portion of total reserves. 

This fee is asymmetric, unlike with Uniswap, which will bias the ratio in one direction. However, one the bias  becomes large enough, an arbitrage opportunity will emerge and someone will correct that bias. This leads to some inefficiencies, but this is necessary as some ERC-1155 tokens are non-fungible (0 decimals) and the fees can only be paid with the base currency. 

# Trades

All trades are done by specifying exactly how many tokens $i$ a user wants to buy or sell, without exactly knowing how much base currency they will send or receive. This design choice was necessary considering ERC-1155 tokens can be non-fungible, unlike the base currency which is assumed to be fungible (non-zero decimals). All trades will update the corresponding base currency and token reserves correctly and will be subjected to a [liquidity provider fee](#liquidity-fee). 

It is possible to buy/sell multiple tokens at once, but if any one fails, the entire trade will fail as well. This could change for Niftyswap V2.

### Base Currency to Token $i$

To trade base currency => token $i$, a user would call 

```solidity
_baseToToken(_tokenIds, _tokensBoughtAmounts, _maxBaseTokens, _deadline, _recipient)
```

as defined in [???](???) and specify *exactly* how many tokens $i$ they expect to receive from the trade. This is done by specifying the token ids to purchase in the `_tokenIds` array and the amount for each token id in the `_tokensBoughtAmounts` array. 

Since users can't know exactly how much base currency will be required when the transaction is created, they must provide a `_maxBaseTokens` value which contain the maximum amount of base currency they are willing to spend for the entire trade. It would've been possible for Niftyswap to support a maximum amount per token $i$, however this would increase the gas cost significantly. If proven to be desired, this could be incorporated in Niftyswap V2.

Additionally, to protect users against miners or third party relayers withholding their Niftyswap trade transactions, a `_deadline` parameter must be provided by the user. This `_deadline`is a block number after which a given transaction will revert.

Finally, users can specify who should receive the tokens with the `_rececipient` argument. This is particularly useful for third parties and proxy contracts that will interact with Niftyswap.

The `bytes4` signature to call this method is `0x87ba033f`

```solidity
// bytes4(keccak256(
//   "BuyTokensObj(address,uint256[],uint256[],uint256)"
// ));
bytes4 internal constant BUYTOKENS_SIG = 0x87ba033f;
```

The `_maxBaseTokens` argument is specified as the amount of base currency sent to the NiftyswapExchange.sol contract via the `onERC1155BatchReceived()` method :

```solidity
// Tokens received need to be Base Currency contract
require(msg.sender == address(baseToken), "NiftyswapExchange#onERC1155BatchReceived: INVALID_BASE_TOKENS_TRANSFERRED");
require(_ids.length == 1, "NiftyswapExchange#onERC1155BatchReceived: INVALID_BASE_TOKEN_ID_AMOUNT");
require(_ids[0] == baseTokenID, "NiftyswapExchange#onERC1155BatchReceived: INVALID_BASE_TOKEN_ID");

// Decode BuyTokensObj from _data to call _baseToToken()
BuyTokensObj memory obj;
(functionSignature, obj) = abi.decode(_data, (bytes4, BuyTokensObj));
address recipient = obj.recipient == address(0x0) ? _from : obj.recipient;

// Buy tokens
_baseToToken(obj.tokensBoughtIDs, obj.tokensBoughtAmounts, _amounts[0], obj.deadline, recipient);
```

where any difference between the actual cost of the trade and the amount sent will be refunded  to the specified recipient.

### Token $i$ to Base Currency

To trade token $i$ => base currency, a user would call 

```solidity
_tokenToBase(_tokenIds, _tokensSoldAmounts, _minBaseTokens, _deadline, _recipient)
```
as defined in [???](???) and specify *exactly* how many tokens $i$ they sell. This is done by specifying the token ids to sell in the `_tokenIds` array and the amount for each token id in the `_tokensSoldAmounts` array. 

Since users can't know exactly how much base currency they would receive when the transaction is created, they must provide a `_minBaseTokens` value which contain the minimum amount of base currency they are willing to accept for the entire trade.  It would've been possible for Niftyswap to support a minimum amount per token $i$, however this would increase the gas cost significantly. If proven to be desired, this could be incorporated in Niftyswap V2.

Additionally, to protect users against miners or third party relayers withholding their Niftyswap trade transactions, a `_deadline` parameter must be provided by the user. This `_deadline`is a block number after which a given transaction will revert.

Finally, users can specify who should receive the base currency with the `_rececipient` argument upon the completion of the trade. This is particularly useful for third parties and proxy contracts that will interact with Niftyswap. 

The `bytes4` signature to call this method is `0x77852e33`

```solidity
// bytes4(keccak256(
//   "SellTokensObj(address,uint256,uint256)"
// ));
bytes4 internal constant SELLTOKENS_SIG = 0x77852e33;
```

The `_tokenIds` and  `_tokensSoldAmounts` arguments are specified as the token ids and token amounts sent to the NiftyswapExchange.sol contract via the `onERC1155BatchReceived()` method :

```solidity
// Tokens received need to be correct ERC-1155 Token contract
require(msg.sender == address(token), "NiftyswapExchange#onERC1155BatchReceived: INVALID_TOKENS_TRANSFERRED");

// Decode SellTokensObj from _data to call _tokenToBase()
SellTokensObj memory obj;
(functionSignature, obj) = abi.decode(_data, (bytes4, SellTokensObj));
address recipient = obj.recipient == address(0x0) ? _from : obj.recipient;

// Sell tokens
_tokenToBase(_ids, _amounts, obj.minBaseTokens, obj.deadline, recipient);
```

# Liquidity Reserves Management

Anyone can provide liquidity for a given token $i$, so long as they also provide liquidity for the corresponding base currency reserve. When adding liquidity to a reserve, liquidity providers should not influence the price, hence the contract ensures that calling `_addLiquidity()` or `_removeLiquidity()` does not change the $BaseReserve_i / TokenReserve_i $ ratio. 

### Adding Liquidity

Similarly to trading, when adding liquidity, 



### Removing Liquidity







## Relevant Methods

Most important methods that handle the balance packing logic can be found in the [ERC1155PackedBalance.sol](???) contract.

### *getIDBinIndex(uint256 _id)*

This method will return the `uint256` storage slot and the index within that storage slot token `_id` occupies. 

### *getValueInBin(uint256 _binAmount, uint256 _index)*

This method will return the value at position `_index` for the provided `uint256` bin referred to as `_binAmount`. 

### *_viewUpdateBinValue(uint256 _binValues, uint256 _index, uint256 _amount, Operations _operation)*

This method will return the updated `_binValues` after the value at `_index` was updated. `_amount` can either be added to or subtracted from the value at `_index`. Whether `_amount` is added or subtracted is specified by `_operation`. This method does not perform an `SSTORE` nor an `SLOAD` operation.

```solidity
// Operations for _updateIDBalance
enum Operations { Add, Sub }
```

The `_viewUpdateBinValue()` method verifies for overflows or underflows depending on whether the operation is an addition or subtraction :

```solidity
if (_operation == Operations.Add) {
  require(((_binValues >> shift) & mask) + _amount < 2**IDS_BITS_SIZE);
  ...

} else if (_operation == Operations.Sub) {
  require(((_binValues >> shift) & mask) >= _amount);
  ...
}
```

### *_updateIDBalance(address _address, uint256 _id, uint256 _amount, Operations _operation)*

This method will directly update the corresponding storage slot where `_id` is registered for the user `_address`. The `_amount` provided will either be added or subtracted based on the `_operation` provided. This methods directly update the storage slot via an `SSTORE` operation. 

### _safeBatchTransferFrom(...) and _batchMint(...)

These method in the [ERC1155PackedBalance](???)  and [ERC1155MintBurnPackedBalance.sol](???) contracts (respectively) take advantage of the packed balances by trying to only read and write once per storage slot when transferring or minting multiple assets. To achieve this, the methods assume the `_ids` provided as argument are sorted in such a way that ids in the same storage slots are consecutive. 

```solidity
for (uint256 i = 1; i < nTransfer; i++) {
  // Get the storage slot (or bin) and corresponding index for _ids[i]
  (bin, index) = getIDBinIndex(_ids[i]);

  // If new storage slot
  if (bin != lastBin) {
    // Update storage balance of previous bin
    balances[_from][lastBin] = balFrom;
    balances[_to][lastBin] = balTo;
	
	// Load in memory new bins
    balFrom = balances[_from][bin];
    balTo = balances[_to][bin];

    // lastBin updated to be the most recent bin queried
    lastBin = bin;
  }

  ...
}
```

# Meta-transactions

The three meta-transactions methods in these ERC-1155 implementations ([metaSafeTransferFrom()](???), [metaSafeBatchTransferFrom()](???) & [metaSetApprovalForAll()](???)) follow a similar structure. These three methods share two meta-transaction relevant arguments, `_isGasFee` and `_data`.

`_isGasFee` : *Boolean* specifying whether gas is reimbursed by user to operator (address executing the transaction), in which case a [Gas Receipt](#gas-receipt) struct must be provided in the `_data` argument.

`_data`: *Bytes array* containing the `signature`, `GasReceipt` struct (optional) and an optional extra byte array (optional).

A meta-transaction's hash must be signed with a [supported signature type](#signature-types), unless if that type is [WalletBytes](#walletbytes) as explained in the corresponding section.

## Meta-Transaction for Asset Transfers

For the `metaSafeTransferFrom(_from, _to, _id, _amount, _isGasFee, _data)` and `metaSafeBatchTransferFrom(_from, _to, _ids, _amounts, _isGasFee, _data)` methods, the `_data` provided must be encoded as `abi.encode(Signature, ?GasReceiptAndTansferData)` where `Signature` is tightly encoded as:

| Offset | Length | Contents                          |
| ------ | ------ | --------------------------------- |
| 0x00   | 32     | r                                 |
| 0x20   | 32     | s                                 |
| 0x40   | 1      | v (always 27 or 28)               |
| 0x41   | 1      | [SignatureType](#signature-types) |

and where `GasReceiptAndTansferData = abi.encode(?GasReceipt, tansferData)` if `_isGasFee` is `true`, else `GasReceiptAndTansferData` is simply `tansferData`.  `tansferData` is a byte array that will be passed to the recipient contract, if any.

### metaSafeTransferFrom() Meta-Transaction Hash

The hash of a meta `safeTransferFrom()` transaction is hashed according to the [EIP712 specification](#https://github.com/ethereum/EIPs/pull/712/files). See the [EIP712 Usage](#eip712-usage) section for information on how to calculate the required domain separator for hashing a `metaSafeTransferFrom()` meta-transaction.

```
// TypeHash for the EIP712 metaSafeTransferFrom Schema
bytes32 constant internal META_TX_TYPEHASH = keccak256(
	"metaSafeTransferFrom(address _from,address _to,uint256 _id,uint256 _amount,uint256 nonce,bytes signedData)"
);

bytes32 metaSafeTransferFromHash = keccak256(abi.encodePacked(
    EIP191_HEADER,
    EIP712_DOMAIN_HASH,
    keccak256(abi.encodePacked(
        META_TX_TYPEHASH,                   // Bytes32
        uint256(_from),                     // Address as uint256
        uint256(_to),                       // Address as uint256
        _id,                                // Uint256
        _amount                             // Uint256
        nonce,                              // Uint256
        keccak256(GasReceiptAndTansferData) // Bytes32
    ))
));
```

### metaSafeBatchTransferFrom() Meta-Transaction Hash

The hash of a meta `batchSafeTransferFrom()` transaction is hashed according to the [EIP712 specification](#https://github.com/ethereum/EIPs/pull/712/files). See the [EIP712 Usage](#eip712-usage) section for information on how to calculate the required domain separator for hashing a `metaSafeBatchTransferFrom()` meta-transaction.

```
// TypeHash for the EIP712 metaSafeBatchTransferFrom Schema
bytes32 constant internal META_BATCH_TX_TYPEHASH = keccak256(
	"metaSafeBatchTransferFrom(address _from,address _to,uint256[] _ids,uint256[] _amounts,uint256 nonce,bytes signedData)"
);

bytes32 metaSafeBatchTransferFromHash = keccak256(abi.encodePacked(
    EIP191_HEADER,
    EIP712_DOMAIN_HASH,
    keccak256(abi.encodePacked(
        META_BATCH_TX_TYPEHASH,               // Bytes32
        uint256(_from),                       // Address as uint256
        uint256(_to),                         // Address as uint256
        keccak256(abi.encodePacked(_ids)),    // Bytes32
        keccak256(abi.encodePacked(_amounts)) // Bytes32
        nonce,                                // Uint256
        keccak256(GasReceiptAndTansferData)   // Bytes32
    ))
));
```

## Meta-Transaction for Approvals

For the `metaSetApprovalForAll(_owner, _operator, _approved, _isGasFee, _data)` method the `_data` provided must be encoded as `abi.encode(Signature, ?GasReceipt)` where `Signature` is tightly encoded as:

| Offset | Length | Contents            |
| ------ | ------ | ------------------- |
| 0x00   | 32     | r                   |
| 0x20   | 32     | s                   |
| 0x40   | 1      | v (always 27 or 28) |
| 0x41   | 1      | SignatureType       |

and where `GasReceipt` is passed if `_isGasFee` is `true`.

### metaSetApprovalForAll() Meta-Transaction Hash

The hash of a meta `setApprovalForAll()` transaction is hashed according to the [EIP712 specification](#https://github.com/ethereum/EIPs/pull/712/files). See the [EIP712 Usage](#eip712-usage) section for information on how to calculate the required domain separator for hashing a `metaSetApprovalForAll()` meta-transaction.

```
// TypeHash for the EIP712 metaSetApprovalForAll Schema
bytes32 constant internal META_APPROVAL_TYPEHASH = keccak256(
	"metaSetApprovalForAll(address _owner,address _operator,bool _approved,uint256 nonce,bytes signedData)"
);

bytes32 metaSetApprovalForAllHash = keccak256(abi.encodePacked(
    EIP191_HEADER,
    EIP712_DOMAIN_HASH,
    keccak256(abi.encodePacked(
        META_APPROVAL_TYPEHASH,             // Bytes32
        uint256(_owner),                    // Address as uint256
        uint256(_operator),                 // Address as uint256
        _approved ? uint256(1) : uint256(0) // Uint256
        nonce,                              // Uint256
        keccak256(GasReceipt)               // Bytes32
    ))
));
```

# Gas Reimbursement

Meta-transaction operators can charge a fee to the signer of the meta-transaction in exchange of paying for the gas in ETH. All three [meta-transaction methods](#meta-transactions) have an`_isGasFee` argument, which indicates whether a [Gas Receipt](#gas-receipt) is expected to be encoded in the `_data` argument. This receipts will determine what the fee will be and in which asset it must be paid. 

At the beginning of each meta-transaction method, a gas counter is started for the remaining of the transaction.

```solidity
uint256 startGas = gasleft();
```

Towards the end of a transaction, the fee to be paid is calculated as follow:

```solidity
// Amount of gas consumed so far
gasUsed = _startGas.sub(gasleft()).add(_g.baseGas);

// Reimburse up to gasLimit (instead of throwing)
fee = gasUsed > _g.gasLimit ? _g.gasLimit.mul(_g.gasPrice) : gasUsed.mul(_g.gasPrice);
```

The `baseGas` value is there to account for gas that was not accounted for by the gas counter, such as the CALLDATA, the expected cost of reimbursing the gas, a supplementary fee required by operator, etc. 

The `gasLimit` value is there to protect the users by imposing a limit on how much gas can be reimbursed to the operator. 

The `gasPrice` is used to dictate the price of each gas unit, similar to the [gasPrice](<https://www.investopedia.com/terms/g/gas-ethereum.asp>) in native Ethereum transactions. 

## Gas Receipt

The `GasReceipt` object passed with a meta-transaction will determine whether the gas will be reimbursed from the `_from` address to the `operator` (i.e. `feeRecipient`) if the meta-transaction is successful. It is entirely up to the operator to verify that the `GasReceipt` signed by the user satisfies their needs. The `GasReceipt` consists of the following fields:

| Elements     | Type    | Description                                                  |
| ------------ | ------- | ------------------------------------------------------------ |
| gasLimit     | uint256 | Max amount of gas that can be reimbursed                     |
| baseGas      | uint256 | Base gas cost, such as the 21k base transaction cost, CALLDATA cost, etc. |
| gasPrice     | address | Price denominated in token X per gas unit                    |
| feeRecipient | address | Address to send gas fee payment to                           |
| feeTokenData | bytes   | Encoded data for token to use to pay for gas                 |

The `feeTokenData` should be structured as followed when the token used for gas fee is an ERC-20:

| Offset | Length | Contents                                             |
| ------ | ------ | ---------------------------------------------------- |
| 0x00   | 32     | Address of the ERC-20 token, left padded with zeroes |
| 0x20   | 1      | FeeTokenType.ERC20                                   |

The `feeTokenData` should be structured as followed when the token used for gas fee is an ERC-1155:

| Offset | Length | Contents                                               |
| ------ | ------ | ------------------------------------------------------ |
| 0x00   | 32     | Address of the ERC-1155 token, left padded with zeroes |
| 0x20   | 32     | Token ID to pay gas fee with, left padded with zeroes  |
| 0x40   | 1      | FeeTokenType.ERC1155                                   |

 where `FeeTokenType` is an enum:

| FeeTokenType byte | FeeTokenType type |
| ----------------- | ----------------- |
| 0x00              | ERC20             |
| 0x01              | ERC1155           |

Any `FeeTokenType` other than these two MUST revert if used in a transaction. 

# Signature Types

All signatures submitted to the ERC-1155 contract are represented as a byte array of arbitrary length, where the last byte (the "signature byte") specifies the signatures type. The signature type is popped from the signature byte array before validation. The following signature types are supported:

| Signature byte | Signature type       |
| -------------- | -------------------- |
| 0x00           | [Illegal](???)       |
| 0x01           | [EIP712](???)        |
| 0x02           | [EthSign](???)       |
| 0x03           | [WalletBytes](???)   |
| 0x04           | [WalletBytes32](???) |

The data being signed is always encoded and hashed according to [EIP-712](<https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md>). The only notable exception is for when the signature type is [WalletBytes](#walletbytes), as described in the corresponding section.

### Illegal

This is the default value of the signature byte. A transaction that includes an Illegal signature will be reverted. Therefore, users must explicitly specify a valid signature type.

### EIP712

An `EIP712` signature is considered valid if the address recovered from calling [`ecrecover`](???) with the given hash and decoded `v`, `r`, `s` values is the same as the specified signer. In this case, the signature is encoded in the following way:

| Offset | Length | Contents            |
| ------ | ------ | ------------------- |
| 0x00   | 32     | r                   |
| 0x20   | 32     | s                   |
| 0x40   | 1      | v (always 27 or 28) |

### EthSign

An `EthSign` signature is considered valid if the address recovered from calling [`ecrecover`](https://github.com/0xProject/0x-protocol-specification/blob/master/v2/v2-specification.md#ecrecover-usage) with the an EthSign-prefixed hash and decoded `v`, `r`, `s` values is the same as the specified signer.

The prefixed `msgHash` is calculated with:

```
string constant ETH_PERSONAL_MESSAGE = "\x19Ethereum Signed Message:\n32";
bytes32 msgHash = keccak256(abi.encodePacked(ETH_PERSONAL_MESSAGE, hash));
```

`v`, `r`, and `s` are encoded in the signature byte array using the same scheme as [EIP712 signatures](???).

### WalletBytes

The `WalletBytes` signature type allows a contract to interact with the ERC-1155 token contract on behalf of any other address(es) by defining its own signature validation function. When used with meta-transaction signing, the `Wallet` contract *is* the signer of the meta-transaction. When using this signature type, the token contract makes a `STATICCALL` to the `Wallet`contract's `isValidSignature` method, which means that signature verification will fail and revert if the `Wallet` attempts to update state. This contract should have the following interface:

```solidity
contract IWallet {
  /** 
   * @notice Verifies that a signature is valid.
   * @param data      Data that was hashed and signed
   * @param signature Proof of signing.
   */ @return Validity of signature for provided data.
  function isValidSignature(
    bytes calldata data,
    bytes calldata signature
  ) external view returns (bytes4 magicValue);
}
```

The `data` passed to the `Wallet` signer is the encoded data according to EIP-712, expect that the ***byte arrays are not hashed***. For that matter, the recipient contract is expected to know how the received data is structured, which is facilitated by the fact that the first 32 bytes of the byte array received is the `typeHash` (see [EIP-712#rationale-for-typehash](<https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#rationale-for-typehash>)). This signature type distinguishes itself from the `WalletBytes32` as it permits the signer `Wallet` to verify the data itself that was signed. A `Wallet` contract's `isValidSignature(bytes,bytes)` method must return the following magic value if successful:

```solidity
bytes4 ERC1271_MAGICVALUE = bytes4(keccak256("isValidSignature(bytes,bytes)"));
```

### WalletBytes32

The `WalletBytes32` signature type allows a contract to trade on behalf of any other address(es) by defining its own signature validation function. When used with order signing, the `Wallet` contract *is* the signer of the meta-transaction. When using this signature type, the token contract makes a `STATICCALL` to the `Wallet`contract's `isValidSignature` method, which means that signature verification will fail and revert if the `Wallet` attempts to update state. This contract should have the following interface:

```solidity
contract IWallet {
  /** 
   * @notice Verifies that a signature is valid.
   * @param hash      Hash that was signed
   * @param signature Proof of signing.
   */ @return Validity of signature for provided data.
  function isValidSignature(
    bytes32 hash,
    bytes calldata signature
  ) external view returns (bytes4 magicValue);
}
```

A `Wallet` contract's `isValidSignature(bytes32,bytes)` method must return the following magic value if successful:

```solidity
bytes4 ERC1271_MAGICVALUE_BYTES32 = bytes4(keccak256("isValidSignature(bytes32,bytes)"));
```

# Events

### 



# Miscellaneous

## EIP712 usage

Hashes of ERC-1155 meta-transactions are calculated according to the [EIP712 specification](https://github.com/ethereum/EIPs/pull/712/files) as follow:

The `EIP191_HEADER` and `EIP712_DOMAIN_HASH` constants are calculated as follow ; 

```solidity
// EIP-191 Header
string constant internal EIP191_HEADER = "\x19\x01";

// Hash of the EIP712 Domain Separator Schema
bytes32 constant internal DOMAIN_SEPARATOR_TYPEHASH = keccak256(abi.encodePacked(
    "EIP712Domain(address verifyingContract)"
));

bytes32 constant internal EIP712_DOMAIN_HASH = keccak256(abi.encodePacked(
	DOMAIN_SEPARATOR_TYPEHASH, 
	uint256(address(this))
));
```

For more information about how this is used, see [hashing an order](#hashing-an-order) and [hashing a transaction](#hash-of-a-transaction).

## ecrecover usage

The `ecrecover` precompile available in Solidity expects `v` to always have a value of `27` or `28`. Some signers and clients assume that `v` will have a value of `0` or `1`, so it may be necessary to add `27` to `v` before submitting it to the `Exchange` contract.
