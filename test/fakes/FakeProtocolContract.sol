// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title FakeProtocolContract
/// @notice A fake protocol contract with configurable state for testing rollback functionality
/// @dev Uses OZ Ownable with Compound Timelock as owner to test proper msg.sender propagation
contract FakeProtocolContract is Ownable {
  uint256 public fee;
  address public feeGuardian;

  event FeeSet(uint256 oldFee, uint256 newFee);
  event FeeGuardianSet(address oldFeeGuardian, address newFeeGuardian);

  /// @notice Constructor sets the Compound Timelock as the owner
  /// @param _timelock The address of the Compound Timelock
  constructor(address _timelock) Ownable(_timelock) {}

  /// @notice Set the fee - can be called by anyone for testing
  /// @param newFee The new fee amount
  function setFee(uint256 newFee) external payable {
    _checkOwner();
    emit FeeSet(fee, newFee);
    fee = newFee;
  }

  /// @notice Set the fee guardian - can be called by anyone for testing
  /// @param newFeeGuardian The new fee guardian address
  function setFeeGuardian(address newFeeGuardian) external {
    _checkOwner();
    emit FeeGuardianSet(feeGuardian, newFeeGuardian);
    feeGuardian = newFeeGuardian;
  }

  /// @notice Allow contract to receive ETH
  receive() external payable {}
}
