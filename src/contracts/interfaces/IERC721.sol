// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address _owner) external view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) external view returns (address owner);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;
    function transferFrom(address _from, address _to, uint256 _tokenId) external;
    function approve(address _to, uint256 _tokenId) external;
    function getApproved(uint256 _tokenId) external view returns (address operator);
    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external;
}
