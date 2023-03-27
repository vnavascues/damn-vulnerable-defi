// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../DamnValuableToken.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        uint256 balanceBefore = token.balanceOf(address(this));

        token.transfer(borrower, amount);
        // @audit OZ's `Address::functionCall()` ends up doing a low-level call (via `functionCallWithValue()`).
        // @audit there is no room for the attacker to withdraw all the funds via `target.functionCall(data)`. The
        // `nonReentrant` reentrancy guard, the balance check after repaying the loan, and the lack of other unprotected
        // functions in `TrusterLenderPool` where to game it (via cross-reentrancy) make clear the strategy must
        // withdrawing the funds after calling/repaying the flash loan.
        // @audit exploit:
        // NB: The attacker can optionally be a smart contract, although only a smart contract will achieve it in a
        // single transaction.
        // 1. The expression above allows the attacker to call `token.approve(<Attacker>, type(uint256).max)` (encoding
        // it as `data` arg).
        // 2. The attacker can call `token.transferFrom(<TrusterLenderPool>, <Attacker>, amount)` once the flash loan
        // has been repaid.
        target.functionCall(data);

        if (token.balanceOf(address(this)) < balanceBefore)
            revert RepayFailed();

        return true;
    }
}
