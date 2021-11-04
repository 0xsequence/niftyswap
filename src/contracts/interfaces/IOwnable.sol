pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

interface IOwnable {
  /**
   * @notice Transfers the ownership of the contract to new address
   * @param _newOwner Address of the new owner
   */
  function transferOwnership(address _newOwner) external;

  /**
   * @notice Returns the address of the owner.
   */
  function getOwner() external view returns (address);
}