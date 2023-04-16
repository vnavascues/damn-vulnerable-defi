// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOwnable} from "./IOwnable.sol";

interface IWalletRegistry is IProxyCreationCallback, IOwnable {
    function addBeneficiary(address _beneficiary) external;

    function proxyCreated(
        GnosisSafeProxy _proxy,
        address _singleton,
        bytes calldata _initializer,
        uint256
    ) external;

    function beneficiaries(address _beneficiary) external view returns (bool);

    function masterCopy() external view returns (address);

    function token() external view returns (address);

    function wallets(address _owner) external view returns (address);

    function walletFactory() external view returns (address);
}
