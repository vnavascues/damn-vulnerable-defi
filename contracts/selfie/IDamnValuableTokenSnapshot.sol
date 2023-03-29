// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IDamnValuableTokenSnapshot is IERC20 {
    function snapshot() external returns (uint256);

    function getBalanceAtLastSnapshot(
        address _account
    ) external view returns (uint256);

    function getTotalSupplyAtLastSnapshot() external view returns (uint256);
}
