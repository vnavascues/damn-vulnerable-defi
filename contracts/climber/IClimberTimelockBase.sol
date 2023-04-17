// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

enum OperationState {
    Unknown,
    Scheduled,
    ReadyForExecution,
    Executed
}

struct Operation {
    uint64 readyAtTimestamp; // timestamp at which the operation will be ready for execution
    bool known; // whether the operation is registered in the timelock
    bool executed; // whether the operation has been executed
}

interface IClimberTimelockBase is IAccessControl {
    function delay() external returns (uint64);

    function operations(bytes32 _id) external returns (Operation memory);

    function getOperationState(
        bytes32 _id
    ) external view returns (OperationState);

    function getOperationId(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _dataElements,
        bytes32 _salt
    ) external pure returns (bytes32);
}
