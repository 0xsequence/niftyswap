// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {INiftyswapExchange} from "src/contracts/interfaces/INiftyswapExchange.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";

import {Constants} from "./Constants.test.sol";
import {Test} from "forge-std/Test.sol";

contract TestHelper is Test, Constants {
    /**
     * Get token balances.
     */
    function getBalances(address owner, uint256[] memory types, address erc1155)
        internal
        view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](types.length);
        for (uint256 i; i < types.length; i++) {
            balances[i] = IERC1155(erc1155).balanceOf(owner, types[i]);
        }
        return balances;
    }

    /**
     * Total of array values.
     */
    function getTotal(uint256[] memory amounts) internal pure returns (uint256 total) {
        for (uint256 i; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    /**
     * Compare first and second balances.
     */
    function assertSame(uint256[] memory first, uint256[] memory second) internal {
        for (uint256 i; i < first.length; i++) {
            assertEq(second[i], first[i]);
        }
    }

    /**
     * Compare first and second balances.
     */
    function assertBeforeAfterDiff(uint256[] memory first, uint256[] memory second, uint256[] memory diff, bool add)
        internal
    {
        for (uint256 i; i < first.length; i++) {
            if (add) {
                assertEq(second[i], first[i] + diff[i]);
            } else {
                assertEq(second[i], first[i] - diff[i]);
            }
        }
    }

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
