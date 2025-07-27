// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/interfaces/IERC2981.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/utils/introspection/ERC165.sol";

abstract contract RoyaltyStandard is ERC165, IERC2981 {
    mapping(uint256 => RoyaltyInfo) public royalties;
    uint16 public constant INVERSE_BASIS_POINT = 10000; // "10000" = 100%

    struct RoyaltyInfo {
        address recipient;
        uint16 feeRate;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId || // ERC-2981 support
            super.supportsInterface(interfaceId);
    }

    function _setTokenRoyalty(
        uint256 tokenId,
        address recipient,
        uint256 value
    ) internal {
        require(recipient != address(0), "RoyaltyStandard: Invalid recipient");
        require(value <= INVERSE_BASIS_POINT, "RoyaltyStandard: Royalty fee too high");
        royalties[tokenId] = RoyaltyInfo(recipient, uint16(value));
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalty = royalties[tokenId];
        receiver = royalty.recipient;
        royaltyAmount = (salePrice * royalty.feeRate) / INVERSE_BASIS_POINT;
    }
}
