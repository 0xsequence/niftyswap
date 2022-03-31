// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;
import "@0xsequence/erc-1155/contracts/mocks/ERC1155MintBurnMock.sol";
import "../interfaces/IERC2981.sol";


contract ERC1155RoyaltyMock is ERC1155MintBurnMock {
  constructor() ERC1155MintBurnMock("TestERC1155", "") {}

  using SafeMath for uint256;
  uint256 public royaltyFee;
  address public royaltyRecipient;
  uint256 public royaltyFee666;
  address public royaltyRecipient666;


  /** 
   * @notice Called with the sale price to determine how much royalty
   *         is owed and to whom.
   * @param _tokenId - the NFT asset queried for royalty information
   * @param _salePrice - the sale price of the NFT asset specified by _tokenId
   * @return receiver - address of who should be sent the royalty payment
   * @return royaltyAmount - the royalty payment amount for _salePrice
   */
  function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
    if (_tokenId == 666) {
      uint256 fee = _salePrice.mul(royaltyFee666).div(10000);
      return (royaltyRecipient666, fee);
    } else {
      uint256 fee = _salePrice.mul(royaltyFee).div(10000);
      return (royaltyRecipient, fee);
    }
  }

  function setFee(uint256 _fee) public {
    require(_fee < 10000, "FEE IS TOO HIGH");
    royaltyFee = _fee;
  }

  function set666Fee(uint256 _fee) public {
    require(_fee < 10000, "FEE IS TOO HIGH");
    royaltyFee666 = _fee;
  }

  function setFeeRecipient(address _recipient) public {
    royaltyRecipient = _recipient;
  }

  function set666FeeRecipient(address _recipient) public {
    royaltyRecipient666 = _recipient;
  }

  bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

  /**
   * @notice Query if a contract implements an interface
   * @param _interfaceID  The interface identifier, as specified in ERC-165
   * @return `true` if the contract implements `_interfaceID` and
   */
  function supportsInterface(bytes4 _interfaceID) public override(ERC1155MintBurnMock) virtual pure returns (bool) {
    // Should be 0x2a55205a
    if (_interfaceID == _INTERFACE_ID_ERC2981) {
      return true;
    }
    return super.supportsInterface(_interfaceID);
  }
}