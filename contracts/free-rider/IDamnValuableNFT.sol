// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC721Burnable} from "./IERC721Burnable.sol";
import {IOwnableRoles} from "./IOwnableRoles.sol";

interface IDamnValuableNFT is IERC721Burnable, IOwnableRoles {
    function safeMint(address _to) external returns (uint256);

    function MINTER_ROLE() external view returns (uint256);

    function tokenIdCounter() external view returns (uint256);
}
