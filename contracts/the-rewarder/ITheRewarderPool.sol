// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {RewardToken} from "./RewardToken.sol";
import {AccountingToken} from "./AccountingToken.sol";

interface ITheRewarderPool {
    function deposit(uint256 _amount) external;

    function distributeRewards() external returns (uint256 rewards);

    function withdraw(uint256 _amount) external;

    function accountingToken() external view returns (AccountingToken);

    function isNewRewardsRound() external view returns (bool);

    function lastRecordedSnapshotTimestamp() external view returns (uint64);

    function lastSnapshotIdForRewards() external view returns (uint128);

    function lastRewardTimestamps(
        address _account
    ) external view returns (uint64);

    function liquidityToken() external view returns (address);

    function rewardToken() external view returns (RewardToken);

    function roundNumber() external view returns (uint64);

    function REWARDS() external view returns (uint256);
}
