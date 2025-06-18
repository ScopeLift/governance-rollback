// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ICompoundTimelock } from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

contract TimelockMultiAdminShim {

   ICompoundTimelock public immutable TIMELOCK;

   constructor(ICompoundTimelock _timelock) {
    TIMELOCK = _timelock;
   }

   function addExecutor(address _newExecutor) public {
    // This method should only be callable by the TIMELOCK *when the transaction originated from the Governor*
    // Ways we might be able to do this:
    // * In the shim, before forwarding to the timelock, cache the address that is making the call,
    // and remember it when the Timelock calls it. Are there timing issues here where we can't know for sure
    // that the transaction executing is the most recently cached executor? This would probably look like the
    // OZ Governor protection that puts operations on the Governor itself into a `_governanceCall` queue. This
    // method would allow the transaction to flow through the timelock, experience the timelock delay, execute
    // from the timelock after the delay, and yet only be executable if the transaction came originally from
    // Governor. ACTUALLY: Aditya points out we don't need a queue. In the `queueTransaction` method, if the
    // sender is not the Governor, but the target is this contract, just revert.
    // * In the queueTransaction method that calls the Timelock, have it observe the target/calldata and use some
    // specific target/calldata combo as a "special" code that can configure the shim but only if sent from
    // the Governor. For example, if the target address is this contract, execute immediately and remove from
    // the list forwarded to the Timelock. This version would skip the time delay for transactions that configure
    // the shim.
   }
}
