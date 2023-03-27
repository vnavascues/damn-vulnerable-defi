// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISideEntranceLenderPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}
