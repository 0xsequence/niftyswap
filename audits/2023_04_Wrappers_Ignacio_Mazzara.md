# Niftyswap - Security Review

**Responses to comments follow in bold.**

## Table of contest

- [Introduction](#introduction)
- [General Notes](#general-notes)
- [Interfaces](#interfaces)
  - [IERC1155FloorFactory.sol](#IERC1155FloorFactory.sol)
  - [IERC1155FloorWrapper.sol](#IERC1155FloorWrapper.sol)
  - [IERC721.sol](#IERC721.sol)
  - [IERC721FloorFactory.sol](#IERC721FloorFactory.sol)
  - [IERC721FloorWrapper.sol](#IERC721FloorWrapper.sol)
  - [IWrapAndNiftyswap.sol](#IWrapAndNiftyswap.sol)
- [Utils](#utils)
  - [Proxy.sol](#Proxy.sol)
  - [WrapperErrors.sol](#WrapperErrors.sol)
  - [WrapperProxyDeployer.sol](#WrapperProxyDeployer.sol)
- [Wrappers](#wrappers)
   - [ERC1155FloorFactory.sol](#ERC1155FloorFactory.sol)
   - [ERC1155FloorWrapper.sol](#ERC1155FloorWrapper.sol)
   - [ERC721FloorFactory.sol](#ERC721FloorFactory.sol)
   - [ERC721FloorWrapper.sol](#ERC721FloorWrapper.sol)
   - [WrapAndNiftyswap.sol](#WrapAndNiftyswap.sol) -> No

## Introduction

0xsequence team requested the review of the contracts under the repository **[niftyswap](https://github.com/0xsequence/niftyswap)** referenced by the commit [dc937eb9ba17e1d4886826fd0579febbe3ecb3ad](https://github.com/0xsequence/niftyswap/pull/79/commits/c89bf42b9585f0018f81803ec09fd2f628b0c52d). Spot at the [PR #79](https://github.com/0xsequence/niftyswap/pull/79/files#diff-447dff6610565178e797d7be963e0fe871eccb314da6a80fe9f6629a0f28184f) the following contracts: _IERC1155FloorFactory.sol_, _IERC1155FloorWrapper.sol_, _IERC721.sol_, _IERC721FloorFactory.sol_, _IERC721FloorWrapper.sol_, _IWrapAndNiftyswap.sol_, _Proxy.sol_, _WrapperErrors.sol_, _WrapperProxyDeployer.sol_, _ERC1155FloorFactory.sol_, _ERC1155FloorWrapper.sol_, _ERC721FloorFactory.sol_, _ERC721FloorWrapper.sol_, _WrapAndNiftyswap.sol_.

The rest of the contracts in the repositories are assumed to be audited.

## General Notes

The _ERC1155FloorWrapper_ wraps and unwraps tokens using the `onERC1155Received` and `onERC1155BatchReceived` functions, but the _ERC721FloorWrapper_ uses specific `deposit` and `withdraw` functions with no support to `onERC721Received`. Using different strategies for the same outcome makes the contract harder to follow and costly for the users in the case of the _ERC721FloorWrapper_. They need an extra transaction to `approve` each token or an `approvalForAll` before depositing. Consider using the same strategy for both wrappers. **ADDRESSED: Updated ERC721FloorWrapper to use receiver functions. Have kept deposit to enable multiple deposits in a single transaction.**

Another thing to have in mind is that the users can claim unwrapped tokens if someone, by mistake, doesn't use the wrappers as expected. This has been addressed before the audit started[here by the team](https://github.com/0xsequence/niftyswap/pull/79#pullrequestreview-1362003788). **IGNORED: Intentional, as stated.**

## Interfaces

### IERC1155FloorFactory.sol

Nothing found.

### IERC1155FloorWrapper.sol

#### Notes

- N1 - line 32 - Wrong return value in the dev notation. It says `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` and it should be bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) **ADDRESSED: Fixed docstring.**

### IERC721.sol

Nothing found.

### IERC721FloorFactory.sol

Nothing found.

### IERC721FloorWrapper.sol

Nothing found.

### IWrapAndNiftyswap

#### Notes

- N1 - lines 12, 18, and 27 - Parameter names start with `_` while other interfaces use another convention. Consider removing the `_` or adding it to other parameter names interfaces. **ADDRESSED: Added _ to new interface function parameters.**

## Utils

### Proxy.sol

### Low

- L1 - line 8 - There is no check whether the implementation is a contract. Consider adding the `isContract` check to prevent human errors. **IGNORED: With CREATE2 it's possible that the proxy may be deployed pointing to a known address before the implementation has been deployed.**

#### Notes

- N1 - line 5 - Consider using the `immutable` keyword for the `implementation` variable since it is not intended to be changed during the contract's lifecycle. This change will reduce gas consumption at deployment and execution. **IGNORED: Assembly access to immutable variables is not supported in solidity 0.8.4.**

### WrapperErrors.sol

Nothing found.

### WrapperProxyDeployer.sol

#### Notes

- N1 - lines 4, 5, 7, 9 - Unused imports. Consider removing them. **ADDRESSED: Removed unused imports.**

- N2 - line 18 - Possibility to create a proxy for the zero address. Consider checking that `tokenAddr` is a contract or at least different from the zero address. **IGNORED: With CREATE2 it's possible that the proxy may be deployed pointing to a known address before the implementation has been deployed.**

- N3 - lines 20, 21, 22, 23 - Consider removing some operations if there is no need to return specific errors. Checking whether the contract was already created can be done off-chain before and after sending the tx. The `WrapperCreationFailed` may be enough. **ADDRESSED: Removed additional checks.**

- N4 - line 25 - Wrong comment. `getProxysalt` returns the salt needed for `create2`, not the resultant address. **ADDRESSED: Comment removed.**

- N5 - lines 38, 43, 50, 54, and 58 - Missing dev notation. **ADDRESSED: Documentation added.**


## Wrappers

### ERC1155FloorFactory.sol

#### Low


- L1 - line 55 - There is no check if the contract being set supports the `IERC1155Metadata` interface and/or if it is at least a contract. Consider adding those checks to prevent human errors. **IGNORED: This can be performed off-chain. In the event of user error the function can be called again to fix the issue. This is consistent with the existing NiftyswapFactory20.sol**

#### Notes

- N1 - 15 and 55 - Function parameter names start with `_` while others do not. Consider removing the `_` or adding it to the rest. **ADDRESSED: Removed _ and updated variable name.**

- N2 - line 15 - Missing dev notation. **ADDRESSED: Added documentation.**


### ERC1155FloorWrapper.sol

#### Low

- L1 - line 30 - There is no check if the contract being set supports the `IERC1155` interface and/or if it is at least a contract. Consider adding those checks to prevent human errors. **IGNORED: With CREATE2 it's possible that the wrapper may be deployed pointing to a known address before the token has been deployed.**

- L2 - line 161 - Possible griefing attack when withdrawing specific tokenIds. If the amount of one of the tokenIds desired is not available, the whole transaction will fail. Consider removing the usage of tokenIds. **IGNORED: This is desired behavour and mirrors existing Niftyswap Exchanges.**

#### Notes

- N1 - lines 23 and 27 - Missing dev notation. **ADDRESSED: Added documentation.**

- N2 - 27 and 174 - Function parameter names start with `_` while others do not. Consider removing the `_` or adding it to the rest. **ADDRESSED: Added _ to all function parameters.**

- N3 - lines 107 and 108 - Consider removing `FIXME` comments. **ADDRESSED: Removed comments.**

- N4 - line 111 - Gas optimization. The `_deposit` function doesn't care about the `tokenIds` array. The `TokensDeposited` event can be emitted directly in `onERC1155Received` and  `onERC1155BatchReceived`. Also, consider moving the recipient check at the beginning of the `_deposit` function to prevent consuming more gas in the case of failure. **ADDRESSED: Followed advice.**


### ERC721FloorFactory.sol

#### Low


- L1 - line 55 - There is no check if the contract being set supports the `IERC1155Metadata` interface and/or if it is at least a contract. Consider adding those checks to prevent human errors. **IGNORED: This can be performed off-chain. In the event of user error the function can be called again to fix the issue. This is consistent with the existing NiftyswapFactory20.sol**

#### Notes

- N1 - lines 15 and 55 - Function parameter names start with `_` while others do not. Consider removing the `_` or adding it to the rest. **ADDRESSED: Added _ to all function parameters.**

- N2 - line 15 - Missing dev notation. **ADDRESSED: Added documentation.**


### ERC721FloorWrapper

### Low

- L1 - line 30 - There is no check if the contract being set supports the `IERC721` interface and/or if it is at least a contract. Consider adding those checks to prevent human errors. **IGNORED: With CREATE2 it's possible that the wrapper may be deployed pointing to a known address before the token has been deployed.**

- L2 - line 55 - Consider checking if the recipient address is not the zero address. **Addressed: Added zero address check.**

- L3 - line 80 - Possible griefing attack when withdrawing specific tokenIds. If one of the tokenIds desired is not available, the whole transaction will fail. Consider removing the usage of tokenIds. **IGNORED: This is desired behavour and mirrors existing Niftyswap Exchanges.**

#### Notes

- N1 - lines 66, 76 and 78 - Consider re-using the `length` variable to reduce gas consumption. **ADDRESSED: Reused length variable.**

- N2 - line 73 - Change ERC-1155 to ERC-721. **ADDRESSED: Fixed documentation.**

- N3 - line 99 - `_id` is the only parameter that starts with `_`. Consider removing the `_` or adding it to other parameter names. **ADDRESSED: Added _ to all function parameters.**



Ignacio Mazzara - April 2023.
