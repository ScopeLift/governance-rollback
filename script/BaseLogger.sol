// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console2} from "forge-std/console2.sol";

contract BaseLogger {
  bool public isLoggingSilenced;

  function setLoggingSilenced(bool _isLoggingSilenced) external {
    isLoggingSilenced = _isLoggingSilenced;
  }

  function _log(string memory _message) internal view {
    if (!isLoggingSilenced) {
      console2.log(_message);
    }
  }

  function _log(string memory _label, address _value) internal view {
    if (!isLoggingSilenced) {
      console2.log(_label, _value);
    }
  }

  function _log(string memory _label, uint256 _value) internal view {
    if (!isLoggingSilenced) {
      console2.log(_label, _value);
    }
  }
}
