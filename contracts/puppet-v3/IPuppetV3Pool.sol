// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20Minimal} from "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface IPuppetV3Pool {
    function borrow(uint256 _borrowAmount) external;

    function calculateDepositOfWETHRequired(
        uint256 _amount
    ) external view returns (uint256);

    function deposits(address _depositor) external view returns (uint256);

    function token() external view returns (IERC20Minimal);

    function uniswapV3Pool() external view returns (IUniswapV3Pool);

    function weth() external view returns (IERC20Minimal);

    function DEPOSIT_FACTOR() external view returns (uint256);

    function TWAP_PERIOD() external view returns (uint32);
}
