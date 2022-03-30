pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../interfaces/IOwnable.sol";

/**
 * @title Ownable
 * @dev The Ownable contract inherits the owner of a parent contract as its owner, 
 * and provides basic authorization control functions, this simplifies the 
 * implementation of "user permissions".
 */
contract DelegatedOwnable {
  address internal ownableParent;

  event ParentOwnerChanged(address indexed previousParent, address indexed newParent);

  /**
   * @dev The Ownable constructor sets the original `ownableParent` of the contract to the specied address
   * @param _firstOwnableParent Address of the first ownable parent contract
   */
  constructor (address _firstOwnableParent) {
    try IOwnable(_firstOwnableParent).getOwner() {
      // Do nothing if parent has ownable function
    } catch {
      revert("DO#1"); // PARENT IS NOT OWNABLE
    }
    ownableParent = _firstOwnableParent;
    emit ParentOwnerChanged(address(0), _firstOwnableParent);
  }

  /**
   * @dev Throws if called by any account other than the master owner.
   */
  modifier onlyOwner() {
    require(msg.sender == getOwner(), "DO#2"); // DelegatedOwnable#onlyOwner: SENDER_IS_NOT_OWNER
    _;
  }

  /**
   * @notice Will use the owner address of another parent contract
   * @param _newParent Address of the new owner
   */
  function changeOwnableParent(address _newParent) public onlyOwner {
    require(_newParent != address(0), "D3"); // DelegatedOwnable#changeOwnableParent: INVALID_ADDRESS
    ownableParent = _newParent;
    emit ParentOwnerChanged(ownableParent, _newParent);
  }

  /**
   * @notice Returns the address of the owner.
   */
  function getOwner() public view returns (address) {
    return IOwnable(ownableParent).getOwner();
  }
}