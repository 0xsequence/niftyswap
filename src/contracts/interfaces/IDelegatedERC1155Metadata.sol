pragma solidity ^0.7.4;

import "./IERC1155Metadata.sol";


interface IDelegatedERC1155Metadata {
  function metadataProvider() external view returns (IERC1155Metadata);
}
