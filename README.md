niftyswap
=========

Niftyswap is an open-source, community built ERC-1155 compatible version of **Uniswap** (https://uniswap.io/). There are some differences compared to the original Uniswap that we would like to outline below:

1. For ERC-1155 tokens, not ERC-20s
2. Base token is not ETH, but needs to be an ERC-1155 (defaut is metaDai, see [here](https://github.com/horizon-games/ERC20-meta-wrapper) for more information).
3. Base fee is 0.7% instead of 0.3% to increase liquidity and as a result decrease price slippage and improve user experience.
4. All fees are taken from base currency (Uniswap takes trading fees on both sides). This will lead to some small inneficiencies which will be corrected via arbitrage.
4. Users do not need to set approvals before their first trade
5. 100% meta-tx friendly for ERC-1155 implementations with native meta-tx functionalities
6. Front-end implementations can add arbitrary fee (in addition to the 0.7%) for tokens with native meta-transactions.
7. Less functions than Uniswap, simpler interface. 

There are pros and cons to these differences and we welcome you to discuss these by openning issues on this repository.


**The contracts have not been audited and are not finalized.**

NiftyswapExchange.sol is the main exchange contract.

## To Install
1. Git clone this repository
2. `yarn install && yarn build && yarn test`

