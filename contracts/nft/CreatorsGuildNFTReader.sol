// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import "./CreatorsGuildNFT.sol";

/**
 * @title CreatorsGuildNFTReader
 * @dev Read-only helper contract to reduce main contract size
 */
contract CreatorsGuildNFTReader {
    CreatorsGuildNFT public immutable nftContract;
    
    constructor(address _nftContract) {
        nftContract = CreatorsGuildNFT(_nftContract);
    }
    
    // Get all tokens owned by a specific address
    function getOwnedTokens(address tokenOwner) external view returns (uint256[] memory) {
        uint256 balance = nftContract.balanceOf(tokenOwner);
        uint256[] memory tokens = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = nftContract.tokenOfOwnerByIndex(tokenOwner, i);
        }
        
        return tokens;
    }
    
    // Get detailed information for all tokens owned by a specific address
    function getOwnedTokensDetailed(address tokenOwner) external view returns (CreatorsGuildNFT.TokenDetail[] memory) {
        uint256[] memory tokenIds = this.getOwnedTokens(tokenOwner);
        CreatorsGuildNFT.TokenDetail[] memory details = new CreatorsGuildNFT.TokenDetail[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            details[i] = CreatorsGuildNFT.TokenDetail({
                tokenId: tokenId,
                metaUrl: nftContract.tokenURI(tokenId),
                currentOwner: tokenOwner,
                creator: nftContract.tokenCreator(tokenId),
                isSBT: nftContract.sbtFlag(tokenId),
                originalInfo: nftContract.originalTokenInfo(tokenId)
            });
        }
        
        return details;
    }
    
    // Get detailed information for all tokens created by a specific creator
    function getTokensByCreatorDetailed(address creator) external view returns (CreatorsGuildNFT.TokenDetail[] memory) {
        uint256[] memory tokenIds = nftContract.creatorTokens(creator);
        CreatorsGuildNFT.TokenDetail[] memory details = new CreatorsGuildNFT.TokenDetail[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            details[i] = CreatorsGuildNFT.TokenDetail({
                tokenId: tokenId,
                metaUrl: nftContract.tokenURI(tokenId),
                currentOwner: nftContract.ownerOf(tokenId),
                creator: creator,
                isSBT: nftContract.isSBT(tokenId),
                originalInfo: nftContract.getOriginalTokenInfo(tokenId)
            });
        }
        
        return details;
    }
    
    // Batch get token details
    function getTokenDetailsBatch(uint256[] calldata tokenIds) external view returns (CreatorsGuildNFT.TokenDetail[] memory) {
        CreatorsGuildNFT.TokenDetail[] memory details = new CreatorsGuildNFT.TokenDetail[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            details[i] = CreatorsGuildNFT.TokenDetail({
                tokenId: tokenId,
                metaUrl: nftContract.tokenURI(tokenId),
                currentOwner: nftContract.ownerOf(tokenId),
                creator: nftContract.tokenCreator(tokenId),
                isSBT: nftContract.sbtFlag(tokenId),
                originalInfo: nftContract.originalTokenInfo(tokenId)
            });
        }
        
        return details;
    }
}