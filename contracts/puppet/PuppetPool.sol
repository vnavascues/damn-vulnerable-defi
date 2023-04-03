// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @title PuppetPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract PuppetPool is ReentrancyGuard {
    using Address for address payable;

    uint256 public constant DEPOSIT_FACTOR = 2;

    address public immutable uniswapPair;
    DamnValuableToken public immutable token;

    mapping(address => uint256) public deposits;

    error NotEnoughCollateral();
    error TransferFailed();

    event Borrowed(
        address indexed account,
        address recipient,
        uint256 depositRequired,
        uint256 borrowAmount
    );

    constructor(address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // Allows borrowing tokens by first depositing two times their value in ETH
    // @audit the goal would be to borrow all the DVT balance (100k) by an affordable amount of ETH (< 35 ETH, from
    // 25 starting ETH plus < 10 exchange ETH). Therefore this pool must be vulnerable to oracle attacks
    // (e.g. extremely unbalancing the liquidity pool).
    function borrow(
        uint256 amount,
        address recipient
    ) external payable nonReentrant {
        // @audit check whether `depositRequired` can be < 35 ETH given an `amount` of 100_000k
        uint256 depositRequired = calculateDepositRequired(amount);

        if (msg.value < depositRequired) revert NotEnoughCollateral();

        if (msg.value > depositRequired) {
            unchecked {
                payable(msg.sender).sendValue(msg.value - depositRequired);
            }
        }

        unchecked {
            deposits[msg.sender] += depositRequired;
        }

        // Fails if the pool doesn't have enough tokens in liquidity
        if (!token.transfer(recipient, amount)) revert TransferFailed();

        emit Borrowed(msg.sender, recipient, depositRequired, amount);
    }

    function calculateDepositRequired(
        uint256 amount
    ) public view returns (uint256) {
        return (amount * _computeOraclePrice() * DEPOSIT_FACTOR) / 10 ** 18;
    }

    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return
            (uniswapPair.balance * (10 ** 18)) / token.balanceOf(uniswapPair);
    }
}
