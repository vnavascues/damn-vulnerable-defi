// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IOwnable {
    function grantRoles(address _user, uint256 _roles) external payable;

    function hasAllRoles(address _user, uint256 _roles) external view;

    function hasAnyRole(address _user, uint256 _roles) external view;

    function renounceRoles(uint256 _roles) external payable;

    function revokeRoles(address _user, uint256 _roles) external payable;

    function rolesOf(address _user) external view;

    function ordinalsFromRoles(
        uint256 _roles
    ) external pure returns (uint8[] memory);

    function rolesFromOrdinals(
        uint8[] memory _ordinals
    ) external pure returns (uint256);
}
