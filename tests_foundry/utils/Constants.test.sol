// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract Constants {
    // Niftyswap Exchange
    bytes4 public constant BUYTOKENS_SIG = 0xb2d81047;
    bytes4 public constant SELLTOKENS_SIG = 0xdb08ec97;
    bytes4 public constant ADDLIQUIDITY_SIG = 0x82da2b73;
    bytes4 public constant REMOVELIQUIDITY_SIG = 0x5c0bf259;
    bytes4 public constant DEPOSIT_SIG = 0xc8c323f9;

    // Niftyswap Exchange 20
    bytes4 internal constant SELLTOKENS20_SIG = 0xade79c7a;
    bytes4 internal constant ADDLIQUIDITY20_SIG = 0x82da2b73;
    bytes4 internal constant REMOVELIQUIDITY20_SIG = 0x5c0bf259;
    bytes4 internal constant DEPOSIT20_SIG = 0xc8c323f9;

    address internal constant OPERATOR = address(1);
    address internal constant USER = address(2);
}
