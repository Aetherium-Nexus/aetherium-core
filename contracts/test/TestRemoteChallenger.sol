// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import {IRemoteChallenger} from "../interfaces/avs/IRemoteChallenger.sol";
import {AetheriumServiceManager} from "../avs/AetheriumServiceManager.sol";

contract TestRemoteChallenger is IRemoteChallenger {
    AetheriumServiceManager internal immutable hsm;

    constructor(AetheriumServiceManager _hsm) {
        hsm = _hsm;
    }

    function challengeDelayBlocks() external pure returns (uint256) {
        return 50400; // one week of eth L1 blocks
    }

    function handleChallenge(address operator) external {
        hsm.freezeOperator(operator);
    }
}
