// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFlashLoanerPoolReceiver {
    function receiveFlashLoan(uint256 _amount) external;
}
