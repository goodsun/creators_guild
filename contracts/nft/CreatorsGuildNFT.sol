// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/security/ReentrancyGuard.sol";
import "./RoyaltyStandard.sol";

contract CreatorsGuildNFT is ERC721Enumerable, RoyaltyStandard, ReentrancyGuard {
    // Storage slot 1: address (20 bytes) + uint96 (12 bytes) = 32 bytes
    address private owner;
    uint96 private mintFee; // Max ~79 billion ether, more than enough
    
    // Storage slot 2: uint16 (2 bytes) + padding
    uint16 private maxFeeRate; // Max 65535 basis points (655.35%)
    
    // Storage slot 3+: individual variables
    uint256 private lastId;
    uint256 private totalBurned;
    
    // Mappings
    mapping(uint256 => string) private metaUrl;
    mapping(uint256 => bool) private sbtFlag;
    mapping(address => uint256) private totalDonations;
    mapping(address => bool) private isCreator;
    mapping(address => uint256[]) private creatorTokens;
    mapping(uint256 => address) private tokenCreator;
    mapping(uint256 => string) private originalTokenInfo;
    mapping(address => bool) private importers;
    
    // Arrays
    address[] private creators;

    // Events
    event ConfigUpdated(uint16 maxFeeRate, uint96 mintFee, string name, string symbol);
    event Withdrawal(address indexed owner, uint256 amount);
    event DonationReceived(address indexed from, address indexed to, uint256 amount);
    event ImporterSet(address indexed importer, bool status);

    /*
    * @param string name string Nft name
    * @param string symbol string
    * @param address creator
    * @param address feeRate Unit is %
    */
    constructor(
        string memory _nameParam,
        string memory _symbolParam
    ) ERC721(_nameParam, _symbolParam) {
        owner = msg.sender;
        mintFee = 5000000000000000; // 0.005 ether
    }

    /*
    * @param address to
    * @param string metaUrl
    */
    function mint(address to, string memory _metaUrl, uint16 feeRate, bool _sbtFlag) public payable {
        require(msg.value >= mintFee, "Insufficient Mint Fee");
        require(feeRate <= maxFeeRate, "over Max Fee Rate");

        if(msg.value > mintFee){
           totalDonations[msg.sender] = totalDonations[msg.sender] + (msg.value - mintFee);
        }

        lastId++;
        uint256 tokenId = lastId;
        metaUrl[tokenId] = _metaUrl;
        sbtFlag[tokenId] = _sbtFlag;
        _mint(to, tokenId);
        _setTokenRoyalty(tokenId, msg.sender, feeRate * 100); // 100 = 1%

        // Track creator
        if (!isCreator[msg.sender]) {
            isCreator[msg.sender] = true;
            creators.push(msg.sender);
        }
        creatorTokens[msg.sender].push(tokenId);
        tokenCreator[tokenId] = msg.sender;
    }

    /*
     * ERC721 0x80ac58cd
     * ERC165 0x01ffc9a7 (RoyaltyStandard)
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721Enumerable, RoyaltyStandard)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return metaUrl[tokenId];
    }

    function burn(uint256 tokenId) external {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId) || msg.sender == owner,
            "Caller is not owner nor approved"
        );
        originalTokenInfo[tokenId] = "";
        metaUrl[tokenId] = "";
        _burn(tokenId);
    }

    function transferFromWithDonation(
        address from,
        address to,
        uint256 tokenId
    ) external payable nonReentrant {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _transfer(from, to, tokenId);
        if (msg.value > 0) {
            totalDonations[to] = totalDonations[to] + msg.value;
            emit DonationReceived(from, to, msg.value);
        }
    }

    function safeTransferFromWithDonation(
        address from,
        address to,
        uint256 tokenId
    ) external payable {
        safeTransferFromWithDonation(from, to, tokenId, "");
    }

    function safeTransferFromWithDonation(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable nonReentrant {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
        if (msg.value > 0) {
            totalDonations[to] = totalDonations[to] + msg.value;
            emit DonationReceived(from, to, msg.value);
        }
    }

    function transferFromWithCashback(
        address from,
        address to,
        uint256 tokenId
    ) external payable nonReentrant {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        require(msg.value > 0, "No value sent");
        require(to != address(0), "Invalid recipient");

        uint256 donation = (msg.value * 90) / 100;
        uint256 cashback = msg.value - donation;

        // State changes first
        _transfer(from, to, tokenId);
        totalDonations[to] = totalDonations[to] + donation;
        emit DonationReceived(from, to, donation);

        // External calls last
        if (cashback > 0) {
            (bool success, ) = payable(to).call{value: cashback}("");
            require(success, "Cashback transfer failed");
        }
    }

    /*
        extra method
     */
    function config(
        uint16 _maxFeeRate,
        uint96 _mintFee
    ) external {
        require(owner == msg.sender, "Can't set. owner only");
        require(_maxFeeRate <= 1000, "Max fee rate too high (max 10%)");
        require(_mintFee <= 1 ether, "Mint fee too high");
        maxFeeRate = _maxFeeRate;
        mintFee = _mintFee;
        emit ConfigUpdated(_maxFeeRate, _mintFee, "", "");
    }

    function withdraw() external nonReentrant {
        require(owner == msg.sender, "Can't withdraw. owner only");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        emit Withdrawal(msg.sender, balance);
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (from != address(0) && to != address(0) && to != 0x000000000000000000000000000000000000dEaD) {
            require(!sbtFlag[tokenId], "SBT: Token transfer not allowed");
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._safeTransfer(ownerOf(tokenId), 0x000000000000000000000000000000000000dEaD, tokenId, "");
        super._burn(tokenId);
        totalBurned++;
    }

    // Getter functions
    function getOwner() external view returns (address) {
        return owner;
    }

    function getMintFee() external view returns (uint256) {
        return mintFee;
    }

    function getMaxFeeRate() external view returns (uint256) {
        return maxFeeRate;
    }

    function getLastId() external view returns (uint256) {
        return lastId;
    }

    function getTotalDonations(address account) external view returns (uint256) {
        return totalDonations[account];
    }

    function isSBT(uint256 tokenId) external view returns (bool) {
        return sbtFlag[tokenId];
    }

    function getOriginalTokenInfo(uint256 tokenId) external view returns (string memory) {
        return originalTokenInfo[tokenId];
    }

    function isImporter(address account) external view returns (bool) {
        return importers[account];
    }

    function getCreators() external view returns (address[] memory) {
        return creators;
    }

    function getCreatorTokens(address creator) external view returns (uint256[] memory) {
        return creatorTokens[creator];
    }

    function getTokenCreator(uint256 tokenId) external view returns (address) {
        return tokenCreator[tokenId];
    }

    function getCreatorCount() external view returns (uint256) {
        return creators.length;
    }

    function getCreatorTokenCount(address creator) external view returns (uint256) {
        return creatorTokens[creator].length;
    }

    function getTotalBurned() external view returns (uint256) {
        return totalBurned;
    }

    function setImporter(address importer, bool status) external {
        require(msg.sender == owner, "Owner only");
        require(importer != address(0), "Invalid importer address");
        importers[importer] = status;
        emit ImporterSet(importer, status);
    }

    // Get all tokens owned by a specific address
    function getOwnedTokens(address tokenOwner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(tokenOwner);
        uint256[] memory tokens = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = tokenOfOwnerByIndex(tokenOwner, i);
        }
        
        return tokens;
    }

    // Get all tokens created by a specific creator (alias for getCreatorTokens)
    function getTokensByCreator(address creator) external view returns (uint256[] memory) {
        return creatorTokens[creator];
    }

    // Import function for external use (called by DonatableNFTImporter)
    function mintImported(
        address to,
        string memory _metaUrl,
        uint16 feeRate,
        bool _sbtFlag,
        address creator,
        string memory _originalInfo
    ) external returns (uint256) {
        require(msg.sender == owner || importers[msg.sender], "Not authorized");

        lastId++;
        uint256 tokenId = lastId;
        metaUrl[tokenId] = _metaUrl;
        sbtFlag[tokenId] = _sbtFlag;
        originalTokenInfo[tokenId] = _originalInfo;

        _mint(to, tokenId);
        _setTokenRoyalty(tokenId, creator, feeRate * 100);

        // Track creator
        if (!isCreator[creator]) {
            isCreator[creator] = true;
            creators.push(creator);
        }
        creatorTokens[creator].push(tokenId);
        tokenCreator[tokenId] = creator;

        return tokenId;
    }
}
