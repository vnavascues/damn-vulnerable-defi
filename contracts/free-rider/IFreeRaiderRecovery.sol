// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IFreeRaiderRecovery is IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory _data
    ) external returns (bytes4);
}
