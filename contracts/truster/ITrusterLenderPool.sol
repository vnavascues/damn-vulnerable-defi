pragma solidity 0.8.19;

import {DamnValuableToken} from "../DamnValuableToken.sol";

interface ITrusterLenderPool {
    function flashLoan(
        uint256 _amount,
        address _borrower,
        address _target,
        bytes calldata _data
    ) external returns (bool);

    function token() external view returns (DamnValuableToken);
}
