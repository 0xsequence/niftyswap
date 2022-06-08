"use strict";
/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
exports.__esModule = true;
exports.INiftyswapExchange20__factory = void 0;
var ethers_1 = require("ethers");
var INiftyswapExchange20__factory = /** @class */ (function () {
    function INiftyswapExchange20__factory() {
    }
    INiftyswapExchange20__factory.connect = function (address, signerOrProvider) {
        return new ethers_1.Contract(address, _abi, signerOrProvider);
    };
    return INiftyswapExchange20__factory;
}());
exports.INiftyswapExchange20__factory = INiftyswapExchange20__factory;
var _abi = [
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "buyer",
                type: "address"
            },
            {
                indexed: true,
                internalType: "address",
                name: "recipient",
                type: "address"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokensSoldIds",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokensSoldAmounts",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "currencyBoughtAmounts",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "address[]",
                name: "extraFeeRecipients",
                type: "address[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "extraFeeAmounts",
                type: "uint256[]"
            },
        ],
        name: "CurrencyPurchase",
        type: "event"
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "provider",
                type: "address"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokenIds",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokenAmounts",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "currencyAmounts",
                type: "uint256[]"
            },
        ],
        name: "LiquidityAdded",
        type: "event"
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "provider",
                type: "address"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokenIds",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokenAmounts",
                type: "uint256[]"
            },
            {
                components: [
                    {
                        internalType: "uint256",
                        name: "currencyAmount",
                        type: "uint256"
                    },
                    {
                        internalType: "uint256",
                        name: "soldTokenNumerator",
                        type: "uint256"
                    },
                    {
                        internalType: "uint256",
                        name: "boughtCurrencyNumerator",
                        type: "uint256"
                    },
                    {
                        internalType: "uint256",
                        name: "totalSupply",
                        type: "uint256"
                    },
                ],
                indexed: false,
                internalType: "struct INiftyswapExchange20.LiquidityRemovedEventObj[]",
                name: "details",
                type: "tuple[]"
            },
        ],
        name: "LiquidityRemoved",
        type: "event"
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "royaltyRecipient",
                type: "address"
            },
            {
                indexed: false,
                internalType: "uint256",
                name: "royaltyFee",
                type: "uint256"
            },
        ],
        name: "RoyaltyChanged",
        type: "event"
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: "address",
                name: "buyer",
                type: "address"
            },
            {
                indexed: true,
                internalType: "address",
                name: "recipient",
                type: "address"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokensBoughtIds",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "tokensBoughtAmounts",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "currencySoldAmounts",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "royaltyAmounts",
                type: "uint256[]"
            },
            {
                indexed: false,
                internalType: "address[]",
                name: "extraFeeRecipients",
                type: "address[]"
            },
            {
                indexed: false,
                internalType: "uint256[]",
                name: "extraFeeAmounts",
                type: "uint256[]"
            },
        ],
        name: "TokensPurchase",
        type: "event"
    },
    {
        inputs: [
            {
                internalType: "uint256[]",
                name: "_tokenIds",
                type: "uint256[]"
            },
            {
                internalType: "uint256[]",
                name: "_tokensBoughtAmounts",
                type: "uint256[]"
            },
            {
                internalType: "uint256",
                name: "_maxCurrency",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_deadline",
                type: "uint256"
            },
            {
                internalType: "address",
                name: "_recipient",
                type: "address"
            },
            {
                internalType: "address[]",
                name: "_extraFeeRecipients",
                type: "address[]"
            },
            {
                internalType: "uint256[]",
                name: "_extraFeeAmounts",
                type: "uint256[]"
            },
        ],
        name: "buyTokens",
        outputs: [
            {
                internalType: "uint256[]",
                name: "",
                type: "uint256[]"
            },
        ],
        stateMutability: "nonpayable",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256",
                name: "_assetBoughtAmount",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetSoldReserve",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetBoughtReserve",
                type: "uint256"
            },
        ],
        name: "getBuyPrice",
        outputs: [
            {
                internalType: "uint256",
                name: "",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256",
                name: "_tokenId",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetBoughtAmount",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetSoldReserve",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetBoughtReserve",
                type: "uint256"
            },
        ],
        name: "getBuyPriceWithRoyalty",
        outputs: [
            {
                internalType: "uint256",
                name: "price",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [],
        name: "getCurrencyInfo",
        outputs: [
            {
                internalType: "address",
                name: "",
                type: "address"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256[]",
                name: "_ids",
                type: "uint256[]"
            },
        ],
        name: "getCurrencyReserves",
        outputs: [
            {
                internalType: "uint256[]",
                name: "",
                type: "uint256[]"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [],
        name: "getFactoryAddress",
        outputs: [
            {
                internalType: "address",
                name: "",
                type: "address"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [],
        name: "getGlobalRoyaltyFee",
        outputs: [
            {
                internalType: "uint256",
                name: "",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [],
        name: "getGlobalRoyaltyRecipient",
        outputs: [
            {
                internalType: "address",
                name: "",
                type: "address"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [],
        name: "getLPFee",
        outputs: [
            {
                internalType: "uint256",
                name: "",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256[]",
                name: "_ids",
                type: "uint256[]"
            },
            {
                internalType: "uint256[]",
                name: "_tokensBought",
                type: "uint256[]"
            },
        ],
        name: "getPrice_currencyToToken",
        outputs: [
            {
                internalType: "uint256[]",
                name: "",
                type: "uint256[]"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256[]",
                name: "_ids",
                type: "uint256[]"
            },
            {
                internalType: "uint256[]",
                name: "_tokensSold",
                type: "uint256[]"
            },
        ],
        name: "getPrice_tokenToCurrency",
        outputs: [
            {
                internalType: "uint256[]",
                name: "",
                type: "uint256[]"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "address",
                name: "_royaltyRecipient",
                type: "address"
            },
        ],
        name: "getRoyalties",
        outputs: [
            {
                internalType: "uint256",
                name: "",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "address",
                name: "_royaltyRecipient",
                type: "address"
            },
        ],
        name: "getRoyaltiesNumerator",
        outputs: [
            {
                internalType: "uint256",
                name: "",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256",
                name: "_assetSoldAmount",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetSoldReserve",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetBoughtReserve",
                type: "uint256"
            },
        ],
        name: "getSellPrice",
        outputs: [
            {
                internalType: "uint256",
                name: "",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256",
                name: "_tokenId",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetSoldAmount",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetSoldReserve",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_assetBoughtReserve",
                type: "uint256"
            },
        ],
        name: "getSellPriceWithRoyalty",
        outputs: [
            {
                internalType: "uint256",
                name: "price",
                type: "uint256"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [],
        name: "getTokenAddress",
        outputs: [
            {
                internalType: "address",
                name: "",
                type: "address"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "uint256[]",
                name: "_ids",
                type: "uint256[]"
            },
        ],
        name: "getTotalSupply",
        outputs: [
            {
                internalType: "uint256[]",
                name: "",
                type: "uint256[]"
            },
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "address",
                name: "",
                type: "address"
            },
            {
                internalType: "address",
                name: "_from",
                type: "address"
            },
            {
                internalType: "uint256[]",
                name: "_ids",
                type: "uint256[]"
            },
            {
                internalType: "uint256[]",
                name: "_amounts",
                type: "uint256[]"
            },
            {
                internalType: "bytes",
                name: "_data",
                type: "bytes"
            },
        ],
        name: "onERC1155BatchReceived",
        outputs: [
            {
                internalType: "bytes4",
                name: "",
                type: "bytes4"
            },
        ],
        stateMutability: "nonpayable",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "address",
                name: "_operator",
                type: "address"
            },
            {
                internalType: "address",
                name: "_from",
                type: "address"
            },
            {
                internalType: "uint256",
                name: "_id",
                type: "uint256"
            },
            {
                internalType: "uint256",
                name: "_amount",
                type: "uint256"
            },
            {
                internalType: "bytes",
                name: "_data",
                type: "bytes"
            },
        ],
        name: "onERC1155Received",
        outputs: [
            {
                internalType: "bytes4",
                name: "",
                type: "bytes4"
            },
        ],
        stateMutability: "nonpayable",
        type: "function"
    },
    {
        inputs: [
            {
                internalType: "address",
                name: "_royaltyRecipient",
                type: "address"
            },
        ],
        name: "sendRoyalties",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
    },
];
