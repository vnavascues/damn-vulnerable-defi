// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IDamnValuableToken as DamnValuableToken} from "./IDamnValuableToken.sol";

interface IPuppetPool {
    function borrow(uint256 _amount, address _recipient) external payable;

    function calculateDepositRequired(
        uint256 _amount
    ) external view returns (uint256);

    function DEPOSIT_FACTOR() external view returns (uint256);

    function deposits(address _borrower) external view returns (uint256);

    function token() external view returns (DamnValuableToken);

    function uniswapPair() external view returns (address);
}
