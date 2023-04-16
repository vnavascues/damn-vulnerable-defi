// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// @dev this is an incomplete interface
// @dev from https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/GnosisSafe.sol
interface IGnosisSafe {
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address _to,
        bytes calldata _data,
        address _fallbackHandler,
        address _paymentToken,
        uint256 _payment,
        address payable _paymentReceiver
    ) external;

    function getThreshold() external view returns (uint256);

    function getOwners() external view returns (address[] memory);
}
