// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGnosisSafeProxyFactory {
    function createProxy(
        address masterCopy,
        bytes calldata data
    ) external returns (address);
}

/**
 * @title  WalletDeployer
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice A contract that allows deployers of Gnosis Safe wallets (v1.1.1) to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of the Gnosis Safe Factory and Master Copy v1.1.1
    IGnosisSafeProxyFactory public constant fact =
        IGnosisSafeProxyFactory(0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B);
    address public constant copy = 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F;

    uint256 public constant pay = 1 ether;
    address public immutable chief = msg.sender;
    address public immutable gem;

    address public mom;

    error Boom();

    constructor(address _gem) {
        gem = _gem;
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     * Can only be called once. TODO: double check.
     */
    function rule(address _mom) external {
        // @audit notes: due to lazy eval it can only be set once (mom != addres(0))
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom;
    }

    /**
     * @notice Allows the caller to deploy a new Safe wallet and receive a payment in return.
     *         If the authorizer is set, the caller must be authorized to execute the deployment.
     * @param wat initialization data to be passed to the Safe wallet
     * @return aim address of the created proxy
     */
    function drop(bytes memory wat) external returns (address aim) {
        aim = fact.createProxy(copy, wat);
        if (mom != address(0) && !can(msg.sender, aim)) {
            revert Boom();
        }
        IERC20(gem).transfer(msg.sender, pay);
    }

    // TODO(0xth3g450pt1m1z0r) put some comments
    function can(address u, address a) public view returns (bool) {
        assembly {
            // @audit notes: loads slot 0 (`mom`)
            let m := sload(0)
            // @audit notes: stops the execution if there is no contract deployed on `mum`
            if iszero(extcodesize(m)) {
                return(0, 0)
            }
            // @audit notes: loads the free memory pointer
            let p := mload(0x40)
            // @audit notes: updates the free memory pointer 68 bytes forward (0x44 = 68 = 4 + 32 + 32), clearly to
            // @audit notes: allocate a function call: function ID + arg1 + arg2
            // @audit notes: it won't re-load the free memory pointer anymore
            mstore(0x40, add(p, 0x44))
            // @audit notes: shifts left `AuthorizerUpgradeable.can(address,address)` function ID 224 bits (28 bytes)
            // @audit notes: and stores it at `p` (allegedly 0x80)
            mstore(p, shl(0xe0, 0x4538c4eb))
            // @audit notes: stores `u` (`user` arg address) at `p + 0x04` (right after the function ID)
            mstore(add(p, 0x04), u)
            // @audit notes: stores `a` (`aim` arg address) at `p + 0x24` (right after `u`)
            mstore(add(p, 0x24), a)
            // @audit notes: static calls `can()` at `mum`, and stops the execution if there was an error
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) {
                return(0, 0)
            }
            // @audit notes: stops the execution if there is a response and it is zero
            if and(not(iszero(returndatasize())), iszero(mload(p))) {
                return(0, 0)
            }
        }
        return true;
    }
}
// ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"]
// ["0xc0ffee254729296a45a3885639AC7E10F9d54979"]
