"use strict";
/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
exports.__esModule = true;
exports.IOwnable__factory = void 0;
var ethers_1 = require("ethers");
var _abi = [
    {
        inputs: [],
        name: "getOwner",
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
                internalType: "address",
                name: "_newOwner",
                type: "address"
            },
        ],
        name: "transferOwnership",
        outputs: [],
        stateMutability: "nonpayable",
        type: "function"
    },
];
var IOwnable__factory = /** @class */ (function () {
    function IOwnable__factory() {
    }
    IOwnable__factory.createInterface = function () {
        return new ethers_1.utils.Interface(_abi);
    };
    IOwnable__factory.connect = function (address, signerOrProvider) {
        return new ethers_1.Contract(address, _abi, signerOrProvider);
    };
    IOwnable__factory.abi = _abi;
    return IOwnable__factory;
}());
exports.IOwnable__factory = IOwnable__factory;