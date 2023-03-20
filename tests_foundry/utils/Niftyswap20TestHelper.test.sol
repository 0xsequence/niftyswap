// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {INiftyswapExchange20} from "src/contracts/interfaces/INiftyswapExchange20.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";

import {TestHelperBase} from "./TestHelperBase.test.sol";

abstract contract Niftyswap20TestHelper is TestHelperBase {
    //
    // Niftyswap20 data encodings
    //
    function encodeAddLiquidity(uint256[] memory maxCurrency, uint256 deadline)
        internal
        pure
        returns (bytes memory data)
    {
        return abi.encode(ADDLIQUIDITY20_SIG, INiftyswapExchange20.AddLiquidityObj(maxCurrency, deadline));
    }

    function encodeRemoveLiquidity(uint256[] memory minCurrency, uint256[] memory minToken, uint256 deadline)
        internal
        pure
        returns (bytes memory data)
    {
        return abi.encode(REMOVELIQUIDITY20_SIG, INiftyswapExchange20.RemoveLiquidityObj(minCurrency, minToken, deadline));
    }

    function encodeSellTokens(
        address recipient,
        uint256 minCurrency,
        address[] memory extraFeeRecipients,
        uint256[] memory extraFeeAmounts,
        uint256 deadline
    )
        internal
        pure
        returns (bytes memory data)
    {
        return abi.encode(
            SELLTOKENS20_SIG,
            INiftyswapExchange20.SellTokensObj(recipient, minCurrency, extraFeeRecipients, extraFeeAmounts, deadline)
        );
    }
}
