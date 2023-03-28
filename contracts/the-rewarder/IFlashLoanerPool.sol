// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DamnValuableToken} from "../DamnValuableToken.sol";

interface IFlashLoanerPool {
    function flashLoan(uint256 _amount) external;

    function liquidityToken() external view returns (DamnValuableToken);
}
