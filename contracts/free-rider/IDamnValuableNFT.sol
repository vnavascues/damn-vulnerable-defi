// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IDamnValuableNFT is IERC721 {
    function safeMint(address _to) external returns (uint256);

    function MINTER_ROLE() external view returns (uint256);

    function tokenIdCounter() external view returns (uint256);

    /* ERC721Burnable */

    function burn(uint256 _tokenId) external;

    /* OwnableRoles */

    function cancelOwnershipHandover() external payable;

    function completeOwnershipHandover(address _pendingOwner) external payable;

    function requestOwnershipHandover() external payable;

    function renounceOwnership() external payable;

    function transferOwnership(address _newOwner) external payable;

    function owner() external view returns (address);

    function ownershipHandoverExpiresAt(
        address _pendingOwner
    ) external view returns (uint256);

    function ownershipHandoverValidFor() external view returns (uint64);

    /* Ownable */

    function grantRoles(address _user, uint256 _roles) external payable;

    function hasAllRoles(address _user, uint256 _roles) external view;

    function hasAnyRole(address _user, uint256 _roles) external view;

    function renounceRoles(uint256 _roles) external payable;

    function revokeRoles(address _user, uint256 _roles) external payable;

    function rolesOf(address _user) external view;

    function ordinalsFromRoles(
        uint256 _roles
    ) external pure returns (uint8[] memory);

    function rolesFromOrdinals(
        uint8[] memory _ordinals
    ) external pure returns (uint256);
}
