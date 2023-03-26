// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapExchange} from "src/contracts/interfaces/INiftyswapExchange.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";

import {Constants} from "./Constants.test.sol";
import {Test} from "forge-std/Test.sol";

abstract contract TestHelperBase is Test, Constants {
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
}
