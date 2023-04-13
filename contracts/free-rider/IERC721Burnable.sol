// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC721Burnable is IERC721 {
    function burn(uint256 _tokenId) external;
}
