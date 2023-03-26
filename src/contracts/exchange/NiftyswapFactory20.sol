// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {NiftyswapExchange20} from "./NiftyswapExchange20.sol";
import {Ownable} from "../utils/Ownable.sol";
import {INiftyswapFactory20} from "../interfaces/INiftyswapFactory20.sol";
import {IDelegatedERC1155Metadata, IERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";

contract NiftyswapFactory20 is INiftyswapFactory20, Ownable, IDelegatedERC1155Metadata {
    // tokensToExchange[erc1155_token_address][currency_address][lp_fee][instance]
    mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => address)))) public override
        tokensToExchange;
    mapping(address => mapping(address => address[])) internal pairExchanges;

    // Metadata implementation
    IERC1155Metadata internal metadataContract; // address of the ERC-1155 Metadata contract

    /**
     * @notice Will set the initial Niftyswap admin
     * @param _admin Address of the initial niftyswap admin to set as Owner
     */
    constructor(address _admin) Ownable(_admin) {} // solhint-disable-line no-empty-blocks

    //
    // Functions
    //

    /**
     * @notice Creates a NiftySwap Exchange for given token contract
     * @param _token    The address of the ERC-1155 token contract
     * @param _currency The address of the ERC-20 token contract
     * @param _lpFee    Fee that will go to LPs.
     * Number between 0 and 1000, where 10 is 1.0% and 100 is 10%.
     * @param _instance Instance # that allows to deploy new instances of an exchange.
     * This is mainly meant to be used for tokens that change their ERC-2981 support.
     */
    function createExchange(address _token, address _currency, uint256 _lpFee, uint256 _instance) public override {
        require(tokensToExchange[_token][_currency][_lpFee][_instance] == address(0x0), "NF20#1"); // NiftyswapFactory20#createExchange: EXCHANGE_ALREADY_CREATED

        // Create new exchange contract
        NiftyswapExchange20 exchange = new NiftyswapExchange20(_token, _currency, _lpFee);

        // Store exchange and token addresses
        tokensToExchange[_token][_currency][_lpFee][_instance] = address(exchange);
        pairExchanges[_token][_currency].push(address(exchange));

        // Emit event
        emit NewExchange(_token, _currency, _instance, _lpFee, address(exchange));
    }

    /**
     * @notice Returns array of exchange instances for a given pair
     * @param _token    The address of the ERC-1155 token contract
     * @param _currency The address of the ERC-20 token contract
     */
    function getPairExchanges(address _token, address _currency) public view override returns (address[] memory) {
        return pairExchanges[_token][_currency];
    }

    //
    // Metadata Functions
    //

    /**
     * @notice Changes the implementation of the ERC-1155 Metadata contract
     * @dev This function changes the implementation for all child exchanges of the factory
     * @param _contract The address of the ERC-1155 Metadata contract
     */
    function setMetadataContract(IERC1155Metadata _contract) external onlyOwner {
        emit MetadataContractChanged(address(_contract));
        metadataContract = _contract;
    }

    /**
     * @notice Returns the address of the ERC-1155 Metadata contract
     */
    function metadataProvider() external view override returns (IERC1155Metadata) {
        return metadataContract;
    }
}
