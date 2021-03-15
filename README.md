Niftyswap
=========

Niftyswap is a decentralized token swap protocol for ERC-1155 tokens on Ethereum. In other words,
Niftyswap is Uniswap for ERC-1155 tokens.

*We are incredibly thankful for the work done by the Uniswap team, without which Niftyswap wouldn't exists.*

## Description

Niftyswap is an implementation of [Uniswap](<https://hackmd.io/@477aQ9OrQTCbVR3fq1Qzxg/HJ9jLsfTz?type=view>), a protocol for automated token exchange on Ethereum. While Uniswap is for trading [ERC-20](<https://eips.ethereum.org/EIPS/eip-20>) tokens, Niftyswap is a protocol for [ERC-1155](<https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md>) tokens. Both are designed to favor ease of use and provide guaranteed access to liquidity on-chain. 

Most exchanges maintain an order book and facilitate matches between buyers and sellers. Niftyswap smart contracts hold liquidity reserves of various tokens, and trades are executed directly against these reserves. Prices are set automatically using the [constant product](https://ethresear.ch/t/improving-front-running-resistance-of-x-y-k-market-makers/1281)  $x*y = K$ market maker mechanism, which keeps overall reserves in relative equilibrium. Reserves are pooled between a network of liquidity providers who supply the system with tokens in exchange for a proportional share of transaction fees. 

An important feature of Nitfyswap is the utilization of a factory/registry contract that deploys a separate exchange contract for each ERC-1155 token contract. These exchange contracts each hold independent reserves of a single fungible ERC-1155 currency and their associated ERC-1155 token id. This allows trades between the [Currency](#currency) and the ERC-1155 tokens based on the relative supplies. 

For more details, see [Specification.pdf](https://github.com/0xsequence/niftyswap/blob/master/SPECIFICATIONS.pdf)


## Getting started

### Install

`yarn add @0xsequence/niftyswap` or `npm install @0xsequence/niftyswap`


# Differences with Uniswap

There are some differences compared to the original Uniswap that we would like to outline below:

1. For ERC-1155 tokens, not ERC-20s
2. Base currency is not ETH, but needs to be an ERC-1155
3. Liquidity fee is 0.5% instead of 0.3%
4. All fees are taken from base currency (Uniswap takes trading fees on both sides). This will lead to some small inneficiencies which will be corrected via arbitrage.
4. Users do not need to set approvals before their first trade
5. 100% native meta-tx friendly for ERC-1155 implementations with native meta-tx functionalities
6. Front-end implementations can add arbitrary fee (in addition to the 0.5%) for tokens with native meta-transactions.
7. Less functions than Uniswap

There are pros and cons to these differences and we welcome you to discuss these by openning issues in this repository.

## Contracts

* [NiftyswapExchange.sol](https://github.com/0xsequence/niftyswap/blob/master/contracts/exchange/NiftyswapExchange.sol): The exchange contract that handles the logic for exchanging assets for a given base token.
* [NiftyswapFactory.sol](https://github.com/0xsequence/niftyswap/blob/master/contracts/exchange/NiftyswapFactory.sol): The exchange factory that allows the creation of nifyswap exchanges for the tokens of a given ERC-1155 token conract and an ERC-1155 base currency.

## Security Review

Niftyswap has been audited by two independant parties and all issues discovered were addressed. 
- [Agustín Aguilar**](https://github.com/0xsequence/niftyswap/blob/master/audits/Security_Audit_Nitfyswap_Horizon_Games_1.pdf)
- [Consensys Diligence](https://github.com/0xsequence/niftyswap/blob/master/audits/April_2020_Balance_Patch_1.md) 

** Agustín was hired as a full-time employee at Horizon after the audit was completed. Agustín did not take part in the writing of Niftyswap contracts.

## Dev env & release

This repository is configured as a yarn workspace, and has multiple pacakge.json files. Specifically,
we have the root ./package.json for the development environment, contract compilation and testing. Contract
source code and distribution files are packaged in "src/package.json".

To release a new version, make sure to bump the version, tag it, and run `yarn release`. The `release` command
will publish the `0xsequence/niftyswap` package in the "src/" folder, separate from the root package. The advantage
here is that application developers who consume `0xsequence/niftyswap` aren't required to install any of the devDependencies
in their toolchains as our build and contract packages are separated.


## LICENSE

Copyright (c) 2017-present [Horizon Blockchain Games Inc](https://horizon.io).

Licensed under [Apache-2.0](./LICENSE)
