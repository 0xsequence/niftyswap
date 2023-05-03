// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC1155FloorFactory} from "src/contracts/interfaces/IERC1155FloorFactory.sol";
import {ERC1155FloorFactory} from "src/contracts/wrappers/ERC1155FloorFactory.sol";
import {ERC1155FloorWrapper} from "src/contracts/wrappers/ERC1155FloorWrapper.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";
import {NiftyswapFactory} from "src/contracts/exchange/NiftyswapFactory.sol";
import {NiftyswapFactory20} from "src/contracts/exchange/NiftyswapFactory20.sol";
import {WrapperErrors} from "src/contracts/utils/WrapperErrors.sol";
import {ERC1155MetadataPrefix} from "src/contracts/utils/ERC1155MetadataPrefix.sol";

import {TestHelperBase} from "./utils/TestHelperBase.test.sol";

import {console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

// Note: Implements IERC1155FloorFactory to access events
contract ERC1155FloorFactoryTest is TestHelperBase, IERC1155FloorFactory, WrapperErrors {
    ERC1155FloorFactory private factory;

    function setUp() external {
        factory = new ERC1155FloorFactory(address(this));
    }

    //
    // Create Wrapper
    //
    function test_createWrapper_happyPath(address tokenAddr) public {
        vm.expectEmit(true, true, true, true, address(factory));
        emit NewERC1155FloorWrapper(tokenAddr);
        startMeasuringGas("Create Wrapper"); // Logs only show when not fuzzing
        address wrapper = factory.createWrapper(tokenAddr);
        stopMeasuringGas();

        assertEq(wrapper, factory.tokenToWrapper(tokenAddr));
    }

    function test_createWrapper_duplicateFails() external {
        address tokenAddr = address(1);
        test_createWrapper_happyPath(tokenAddr);

        vm.expectRevert(abi.encodeWithSelector(WrapperCreationFailed.selector, tokenAddr));
        factory.createWrapper(tokenAddr);
    }

    //
    // Metadata
    //
    function test_metadataProvider_happyPath() external {
        ERC1155MetadataPrefix metadata = new ERC1155MetadataPrefix("ipfs://", true, address(this));
        address metadataAddr = address(metadata);
        vm.expectEmit(true, true, true, true, address(factory));
        emit MetadataContractChanged(metadataAddr);
        factory.setMetadataContract(metadata);

        assertEq(address(factory.metadataProvider()), metadataAddr);
    }

    //
    // Helpers
    //

    /**
     * Skip a test.
     */
    modifier skipTest() {
        // solhint-disable-next-line no-console
        console.log("Test skipped");
        if (false) {
            // Required for compiler
            _;
        }
    }

    //
    // Interface overrides
    //
    function createWrapper(address) external pure returns (address) {
        revert UnsupportedMethod();
    }

    function tokenToWrapper(address) external pure returns (address) {
        revert UnsupportedMethod();
    }
}
