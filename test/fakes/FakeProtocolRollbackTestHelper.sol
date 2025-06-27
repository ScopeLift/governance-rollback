// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {CompoundGovernorHelper} from "test/helpers/CompoundGovernorHelper.sol";
import {IUpgradeRegressionManager} from "src/interfaces/IUpgradeRegressionManager.sol";

/// @title FakeProtocolRollbackTestHelper
/// @notice Helper functions for testing rollback scenarios with FakeProtocolContract
contract FakeProtocolRollbackTestHelper {
  FakeProtocolContract public fakeProtocolContract;
  IUpgradeRegressionManager public upgradeRegressionManager;

  constructor(FakeProtocolContract _fakeProtocolContract, IUpgradeRegressionManager _upgradeRegressionManager) {
    fakeProtocolContract = _fakeProtocolContract;
    upgradeRegressionManager = _upgradeRegressionManager;
  }

  /// @notice Generates rollback data for changing the fee and feeGuardian of FakeProtocolContract
  /// @param _rollbackFee The rollback fee to set
  /// @param _rollbackFeeGuardian The rollback fee guardian to set
  /// @return _targets Array of target addresses
  /// @return _values Array of ETH values to send
  /// @return _calldatas Array of encoded function calls
  /// @return _description The description of the rollback
  function generateRollbackData(uint256 _rollbackFee, address _rollbackFeeGuardian)
    public
    view
    returns (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, string memory _description)
  {
    // Create rollback targets (FakeProtocolContract)
    _targets = new address[](2);
    _targets[0] = address(fakeProtocolContract);
    _targets[1] = address(fakeProtocolContract);

    // Create values (0 ETH for both calls)
    _values = new uint256[](2);
    _values[0] = 0;
    _values[1] = 0;

    // Create calldatas for rollback functions
    _calldatas = new bytes[](2);
    _calldatas[0] = abi.encodeWithSelector(FakeProtocolContract.setFee.selector, _rollbackFee);
    _calldatas[1] = abi.encodeWithSelector(FakeProtocolContract.setFeeGuardian.selector, _rollbackFeeGuardian);

    _description = "Emergency rollback for FakeProtocolContract";
  }

  /// @notice Generates the rollback ID for a given set of parameters
  /// @param _rollbackFee The rollback fee to set
  /// @param _rollbackFeeGuardian The rollback fee guardian to set
  /// @return The rollback ID
  function getRollbackId(uint256 _rollbackFee, address _rollbackFeeGuardian) public view returns (uint256) {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, string memory _description) =
      generateRollbackData(_rollbackFee, _rollbackFeeGuardian);
    return upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);
  }

  /// @notice Generates double-encoded URM propose data for rollback
  /// @param _rollbackFee The rollback fee to set in rollback
  /// @param _rollbackFeeGuardian The rollback fee guardian to set in rollback
  /// @return _target The target address (URM)
  /// @return _value The ETH value to send
  /// @return _calldata The encoded URM.propose call
  function generateURMProposeData(uint256 _rollbackFee, address _rollbackFeeGuardian)
    public
    view
    returns (address _target, uint256 _value, bytes memory _calldata)
  {
    // Get the rollback data
    (
      address[] memory _rollbackTargets,
      uint256[] memory _rollbackValues,
      bytes[] memory _rollbackCalldatas,
      string memory _description
    ) = generateRollbackData(_rollbackFee, _rollbackFeeGuardian);

    // Create the URM.propose() calldata
    bytes memory _urmProposeCalldata = abi.encodeWithSelector(
      IUpgradeRegressionManager.propose.selector, _rollbackTargets, _rollbackValues, _rollbackCalldatas, _description
    );

    // Create governance proposal data
    _target = address(upgradeRegressionManager);
    _value = 0;
    _calldata = _urmProposeCalldata;

    return (_target, _value, _calldata);
  }

  /// @notice Generates a complete proposal with rollback in CompoundGovernorHelper.Proposal format
  /// @param _newFee The new fee to set in the main proposal
  /// @param _newFeeGuardian The new fee guardian to set in the main proposal
  /// @param _rollbackFee The fee to set in the rollback (usually original fee)
  /// @param _rollbackFeeGuardian The fee guardian to set in the rollback (usually original fee guardian)
  /// @return _proposal The complete proposal structure
  function generateProposalWithRollback(
    uint256 _newFee,
    address _newFeeGuardian,
    uint256 _rollbackFee,
    address _rollbackFeeGuardian
  ) public view returns (CompoundGovernorHelper.Proposal memory _proposal) {
    return generateProposalWithRollbackAndAmount(_newFee, _newFeeGuardian, 0, _rollbackFee, _rollbackFeeGuardian);
  }

  /// @notice Generates a complete proposal with rollback and ETH amount in CompoundGovernorHelper.Proposal format
  /// @param _newFee The new fee to set in the main proposal
  /// @param _newFeeGuardian The new fee guardian to set in the main proposal
  /// @param _amount The amount of ETH to send with the fee change
  /// @param _rollbackFee The fee to set in the rollback (usually original fee)
  /// @param _rollbackFeeGuardian The fee guardian to set in the rollback (usually original fee guardian)
  /// @return _proposal The complete proposal structure
  function generateProposalWithRollbackAndAmount(
    uint256 _newFee,
    address _newFeeGuardian,
    uint256 _amount,
    uint256 _rollbackFee,
    address _rollbackFeeGuardian
  ) public view returns (CompoundGovernorHelper.Proposal memory _proposal) {
    // Generate the main proposal data (set new fee and fee guardian with ETH)
    address[] memory _targets = new address[](3);
    uint256[] memory _values = new uint256[](3);
    bytes[] memory _calldatas = new bytes[](3);

    // First transaction: set fee
    _targets[0] = address(fakeProtocolContract);
    _values[0] = _amount;
    _calldatas[0] = abi.encodeWithSelector(FakeProtocolContract.setFee.selector, _newFee);

    // Second transaction: set fee guardian
    _targets[1] = address(fakeProtocolContract);
    _values[1] = 0;
    _calldatas[1] = abi.encodeWithSelector(FakeProtocolContract.setFeeGuardian.selector, _newFeeGuardian);

    // Third transaction: rollback
    (address _rollbackTarget, uint256 _rollbackValue, bytes memory _rollbackCalldata) =
      generateURMProposeData(_rollbackFee, _rollbackFeeGuardian);

    _targets[2] = _rollbackTarget;
    _values[2] = _rollbackValue;
    _calldatas[2] = _rollbackCalldata;

    _proposal = CompoundGovernorHelper.Proposal({
      targets: _targets,
      values: _values,
      calldatas: _calldatas,
      description: "Proposal to set FakeProtocolContract update fee and fee guardian with ETH and emergency rollback capability"
    });
  }
}
