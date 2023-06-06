// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {console} from "forge-std/Test.sol";

abstract contract GasHelper {
    string private checkpointLabel;
    uint256 private checkpointGasLeft = 1; // Start the slot warm.

    function startMeasuringGas(string memory label) internal virtual {
        checkpointLabel = label;
        checkpointGasLeft = gasleft();
    }

    function stopMeasuringGas() internal virtual {
        uint256 checkpointGasLeft2 = gasleft();

        // Subtract 100 to account for the warm SLOAD in startMeasuringGas.
        uint256 gasDelta = checkpointGasLeft - checkpointGasLeft2 - 100;

        // solhint-disable-next-line no-console
        console.log(checkpointLabel, "= Gas", gasDelta);
    }
}
