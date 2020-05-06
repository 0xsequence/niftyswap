niftyswap
=========

Niftyswap is an open-source, community built ERC-1155 compatible version of **Uniswap** (https://uniswap.io/). There are some differences compared to the original Uniswap that we would like to outline below:

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

[NiftyswapExchange.sol](https://github.com/arcadeum/niftyswap/blob/master/contracts/exchange/NiftyswapExchange.sol): The exchange contract that handles the logic for exchanging assets for a given base token.
[NiftyswapFactory.sol](https://github.com/arcadeum/niftyswap/blob/master/contracts/exchange/NiftyswapFactory.sol): The exchange factory that allows the creation of nifyswap exchanges for the tokens of a given ERC-1155 token conract and an ERC-1155 base currency.

## Security
Niftyswap has been audited by two independant parties and all issues discovered were addressed. 
- [Agustín Aguilar**](https://github.com/arcadeum/niftyswap/blob/master/audits/Security_Audit_Nitfyswap_Horizon_Games_1.pdf)
- [Consensys Diligence](https://github.com/arcadeum/niftyswap/blob/master/audits/April_2020_Balance_Patch_1.md) 

** Agustín was hired as a full-time employee at Horizon after the audit was completed. Agustín did not take part in the writing of Niftyswap contracts.

## To Install
1. Git clone this repository
2. Install node v11 and yarn (npm install -g yarn)
3. `yarn install`
4. `yarn build`
5. `yarn ganache`
6. in another terminal run, `yarn test` - executes test suite

