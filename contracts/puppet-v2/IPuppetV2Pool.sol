// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPuppetV2Pool {
    function borrow(uint256 _borrowAmount) external;

    function deposits(address _borrower) external view returns (uint256);

    function calculateDepositOfWETHRequired(
        uint256 _tokenAmount
    ) external view returns (uint256);
}
