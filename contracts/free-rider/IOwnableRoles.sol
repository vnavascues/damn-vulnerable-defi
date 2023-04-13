// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IOwnable} from "./IOwnable.sol";

interface IOwnableRoles is IOwnable {
    function cancelOwnershipHandover() external payable;

    function completeOwnershipHandover(address _pendingOwner) external payable;

    function requestOwnershipHandover() external payable;

    function renounceOwnership() external payable;

    function transferOwnership(address _newOwner) external payable;

    function owner() external view returns (address);

    function ownershipHandoverExpiresAt(
        address _pendingOwner
    ) external view returns (uint256);

    function ownershipHandoverValidFor() external view returns (uint64);
}
