// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.4;

import "../interfaces/IERC1155Metadata.sol";
import "./Ownable.sol";


contract ERC1155MetadataPrefix is IERC1155Metadata, Ownable {
  string public uriPrefix;

  event URIPrefixChanged(string _uriPrefix);

  bool immutable includeAddress;

  constructor(string memory _prefix, bool _includeAddress) Ownable(msg.sender) {
    emit URIPrefixChanged(_prefix);
    uriPrefix = _prefix;
    includeAddress = _includeAddress;
  }

  function setUriPrefix(string calldata _uriPrefix) external onlyOwner {
    emit URIPrefixChanged(_uriPrefix);
    uriPrefix = _uriPrefix;
  }

  function uri(uint256 _id) external override view returns (string memory) {
    string memory suffix = _uint256toString(_id);

    if (includeAddress) {
      suffix = string(abi.encodePacked(suffix, "@", _addressToString(msg.sender)));
    }

    return string(abi.encodePacked(uriPrefix, suffix));
  }

  function _addressToString(address account) public pure returns(string memory) {
    return _bytesToString(abi.encodePacked(account));
  }

  function _bytesToString(bytes memory data) public pure returns(string memory) {
    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(2 + data.length * 2);
    str[0] = "0";
    str[1] = "x";
    for (uint i = 0; i < data.length; i++) {
      str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
      str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
    }

    return string(str);
  }

  function _uint256toString(uint256 _id) internal pure returns (string memory) {
    bytes memory reversed = new bytes(78);

    uint256 v = _id;
    uint256 i = 0;
    while (v != 0) {
      uint256 remainder = v % 10;
      v = v / 10;
      reversed[i++] = byte(uint8(48 + remainder));
    }

    bytes memory s = new bytes(i);
    for (uint256 j = 0; j < i; j++) {
      s[j] = reversed[i - 1 - j];
    }

    return string(s);
  }
}
