// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface INiftyswapFactory20 {
    /**
     * |
     * |               Events              |
     * |__________________________________
     */

    event NewExchange(
        address indexed token, address indexed currency, uint256 indexed salt, uint256 lpFee, address exchange
    );

    event MetadataContractChanged(address indexed metadataContract);

    /**
     * |
     * |         Public  Functions         |
     * |__________________________________
     */

    /**
     * @notice Creates a NiftySwap Exchange for given token contract
     * @param _token      The address of the ERC-1155 token contract
     * @param _currency   The address of the currency token contract
     * @param _lpFee      Fee that will go to LPs
     * Number between 0 and 1000, where 10 is 1.0% and 100 is 10%.
     * @param _instance   Instance # that allows to deploy new instances of an exchange.
     * This is mainly meant to be used for tokens that change their ERC-2981 support.
     */
    function createExchange(address _token, address _currency, uint256 _lpFee, uint256 _instance) external;

    /**
     * @notice Return address of exchange for corresponding ERC-1155 token contract
     * @param _token      The address of the ERC-1155 token contract
     * @param _currency   The address of the currency token contract
     * @param _lpFee      Fee that will go to LPs.
     * @param _instance   Instance # that allows to deploy new instances of an exchange.
     * This is mainly meant to be used for tokens that change their ERC-2981 support.
     */
    function tokensToExchange(address _token, address _currency, uint256 _lpFee, uint256 _instance)
        external
        view
        returns (address);

    /**
     * @notice Returns array of exchange instances for a given pair
     * @param _token    The address of the ERC-1155 token contract
     * @param _currency The address of the ERC-20 token contract
     */
    function getPairExchanges(address _token, address _currency) external view returns (address[] memory);
}
