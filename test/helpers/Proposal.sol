// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Proposal
/// @notice A struct that represents a proposal
struct Proposal {
  address[] targets;
  uint256[] values;
  bytes[] calldatas;
  string description;
}
