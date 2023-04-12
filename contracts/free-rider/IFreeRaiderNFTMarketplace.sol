// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DamnValuableNFT} from "../DamnValuableNFT.sol";

interface IFreeRaiderNFTMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;

    function offerMany(
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external;

    function offersCount() external view returns (uint256);

    function token() external view returns (DamnValuableNFT);
}
