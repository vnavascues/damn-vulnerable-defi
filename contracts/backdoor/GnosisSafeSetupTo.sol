// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IDamnValuableToken} from "./IDamnValuableToken.sol";
import {IGnosisSafeSetupTo} from "./IGnosisSafeSetupTo.sol";

contract GnosisSafeSetupTo is IGnosisSafeSetupTo {
    function approve(address _dvt, address _spender) external {
        IDamnValuableToken(_dvt).approve(_spender, type(uint256).max);
    }
}
