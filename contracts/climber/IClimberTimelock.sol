// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IClimberTimelockBase} from "./IClimberTimelockBase.sol";

interface IClimberTimelock is IClimberTimelockBase {
    function execute(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _dataElements,
        bytes32 _salt
    ) external payable;

    function schedule(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _dataElements,
        bytes32 _salt
    ) external;

    function updateDelay(uint64 _newDelay) external;
}
