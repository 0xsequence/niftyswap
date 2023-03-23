// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapExchange} from "src/contracts/interfaces/INiftyswapExchange.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {ADDLIQUIDITY_SIG, REMOVELIQUIDITY_SIG, BUYTOKENS_SIG, SELLTOKENS_SIG} from "./Constants.test.sol";

library NiftyswapTestHelper {
    //
    // Niftyswap data encodings
    //
    function encodeAddLiquidity(uint256[] memory maxCurrency, uint256 deadline)
        internal
        pure
        returns (bytes memory data)
    {
        return abi.encode(ADDLIQUIDITY_SIG, INiftyswapExchange.AddLiquidityObj(maxCurrency, deadline));
    }

    function encodeRemoveLiquidity(uint256[] memory minCurrency, uint256[] memory minToken, uint256 deadline)
        internal
        pure
        returns (bytes memory data)
    {
        return abi.encode(REMOVELIQUIDITY_SIG, INiftyswapExchange.RemoveLiquidityObj(minCurrency, minToken, deadline));
    }

    function encodeBuyTokens(address recipient, uint256[] memory types, uint256[] memory amounts, uint256 deadline)
        internal
        pure
        returns (bytes memory data)
    {
        return abi.encode(BUYTOKENS_SIG, INiftyswapExchange.BuyTokensObj(recipient, types, amounts, deadline));
    }

    function encodeSellTokens(address recipient, uint256 amount, uint256 deadline)
        internal
        pure
        returns (bytes memory data)
    {
        return abi.encode(SELLTOKENS_SIG, INiftyswapExchange.SellTokensObj(recipient, amount, deadline));
    }
}
