// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";

/// @title RollbackTransactionGenerator
/// @notice Utility library for generating random rollback transactions
library RollbackTransactionGenerator {
  /// @notice Generate a rollback proposal with random transactions
  /// @param _rollbackFee Fee parameter for randomization
  /// @param _rollbackGuardian Guardian parameter for randomization
  /// @param _targets Array of target contracts to choose from
  /// @param _selectors Array of function selectors to choose from
  /// @return _targets Array of target addresses
  /// @return _values Array of values
  /// @return _calldatas Array of calldata
  function generateRandomRollbackTransactions(
    uint256 _rollbackFee,
    address _rollbackGuardian,
    FakeProtocolContract[] memory _inputTargets,
    bytes4[] memory _selectors
  ) internal pure returns (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) {
    // Randomly decide between 1 or 2 rollback transactions
    uint256 _numTransactions = (_rollbackFee % 2) + 1; // 1 or 2

    // Create rollback transaction arrays
    _targets = new address[](_numTransactions);
    _values = new uint256[](_numTransactions);
    _calldatas = new bytes[](_numTransactions);

    for (uint256 _i = 0; _i < _numTransactions; _i++) {
      // Select a random target for each transaction - use bound to prevent overflow
      uint256 _targetIndex = _rollbackFee % _inputTargets.length;
      FakeProtocolContract _target = _inputTargets[_targetIndex];

      // Select a random selector for each transaction - use bound to prevent overflow
      uint256 _selectorIndex = uint256(uint160(_rollbackGuardian)) % _selectors.length;
      bytes4 _selector = _selectors[_selectorIndex];

      _targets[_i] = address(_target);
      _values[_i] = 0;

      // Encode the calldata based on the selector
      if (_selector == FakeProtocolContract.setFee.selector) {
        _calldatas[_i] = abi.encodeWithSelector(_selector, _rollbackFee);
      } else {
        _calldatas[_i] = abi.encodeWithSelector(_selector, _rollbackGuardian);
      }
    }
  }
}
