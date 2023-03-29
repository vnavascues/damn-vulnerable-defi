// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IDamnValuableTokenSnapshot} from "./IDamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";

interface ISelfiePool is IERC3156FlashLender {
    function emergencyExit(address receiver) external;

    function CALLBACK_SUCCESS() external view returns (bytes32);

    function governance() external view returns (SimpleGovernance);

    function token() external view returns (IDamnValuableTokenSnapshot);
}
