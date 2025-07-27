// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/security/ReentrancyGuard.sol";
import "./RoyaltyStandard.sol";

contract CreatorsGuildNFT is ERC721Enumerable, RoyaltyStandard, ReentrancyGuard {
    address public owner;
    uint96 public mintFee;
    uint16 public maxFeeRate;
    uint128 public lastId;
    uint128 public totalBurned;

    mapping(uint256 => string) public metaUrl;
    mapping(uint256 => bool) public sbtFlag;
    mapping(address => uint256) public totalDonations;
    mapping(address => bool) private isCreator;
    mapping(address => uint256[]) public creatorTokens;
    mapping(uint256 => address) public tokenCreator;
    mapping(uint256 => string) public originalTokenInfo;
    mapping(address => bool) public importers;

    address[] private creators;

    struct TokenDetail {
        uint256 tokenId;
        string metaUrl;
        address currentOwner;
        address creator;
        bool isSBT;
        string originalInfo;
    }

    event ConfigUpdated(uint16 maxFeeRate, uint96 mintFee, string name, string symbol);
    event Withdrawal(address indexed owner, uint256 amount);
    event DonationReceived(address indexed from, address indexed to, uint256 amount);
    event ImporterSet(address indexed importer, bool status);

    constructor(
        string memory _nameParam,
        string memory _symbolParam
    ) ERC721(_nameParam, _symbolParam) {
        owner = msg.sender;
        mintFee = 5000000000000000;
    }

    function mint(address to, string memory _metaUrl, uint16 feeRate, bool _sbtFlag) public payable {
        require(msg.value >= mintFee, "E1");
        require(feeRate <= maxFeeRate, "E2");

        if(msg.value > mintFee){
           totalDonations[msg.sender] = totalDonations[msg.sender] + (msg.value - mintFee);
        }

        lastId++;
        uint256 tokenId = lastId;
        metaUrl[tokenId] = _metaUrl;
        sbtFlag[tokenId] = _sbtFlag;
        _mint(to, tokenId);
        _setTokenRoyalty(tokenId, msg.sender, feeRate * 100);

        if (!isCreator[msg.sender]) {
            isCreator[msg.sender] = true;
            creators.push(msg.sender);
        }
        creatorTokens[msg.sender].push(tokenId);
        tokenCreator[tokenId] = msg.sender;
    }

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
            "E15"
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "E3");
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "E3");
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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "E3");
        require(msg.value > 0, "E4");
        require(to != address(0), "E5");

        uint256 donation = (msg.value * 90) / 100;
        uint256 cashback = msg.value - donation;

            _transfer(from, to, tokenId);
        totalDonations[to] = totalDonations[to] + donation;
        emit DonationReceived(from, to, donation);

            if (cashback > 0) {
            (bool success, ) = payable(to).call{value: cashback}("");
            require(success, "E6");
        }
    }

    function config(
        uint16 _maxFeeRate,
        uint96 _mintFee
    ) external {
        require(owner == msg.sender, "E7");
        require(_maxFeeRate <= 1000, "E8");
        require(_mintFee <= 1 ether, "E9");
        maxFeeRate = _maxFeeRate;
        mintFee = _mintFee;
        emit ConfigUpdated(_maxFeeRate, _mintFee, "", "");
    }

    function withdraw() external nonReentrant {
        require(owner == msg.sender, "E7");
        uint256 balance = address(this).balance;
        require(balance > 0, "E10");
        emit Withdrawal(msg.sender, balance);
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "E11");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (from != address(0) && to != address(0) && to != 0x000000000000000000000000000000000000dEaD) {
            require(!sbtFlag[tokenId], "E12");
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._safeTransfer(ownerOf(tokenId), 0x000000000000000000000000000000000000dEaD, tokenId, "");
        super._burn(tokenId);
        totalBurned++;
    }


    function getCreators() external view returns (address[] memory) {
        return creators;
    }


    function getCreatorCount() external view returns (uint256) {
        return creators.length;
    }

    function getCreatorTokenCount(address creator) external view returns (uint256) {
        return creatorTokens[creator].length;
    }


    function setImporter(address importer, bool status) external {
        require(msg.sender == owner, "E7");
        require(importer != address(0), "E13");
        importers[importer] = status;
        emit ImporterSet(importer, status);
    }



    function mintImported(
        address to,
        string memory _metaUrl,
        uint16 feeRate,
        bool _sbtFlag,
        address creator,
        string memory _originalInfo
    ) external returns (uint256) {
        require(msg.sender == owner || importers[msg.sender], "E14");

        lastId++;
        uint256 tokenId = lastId;
        metaUrl[tokenId] = _metaUrl;
        sbtFlag[tokenId] = _sbtFlag;
        originalTokenInfo[tokenId] = _originalInfo;

        _mint(to, tokenId);
        _setTokenRoyalty(tokenId, creator, feeRate * 100);

        if (!isCreator[creator]) {
            isCreator[creator] = true;
            creators.push(creator);
        }
        creatorTokens[creator].push(tokenId);
        tokenCreator[tokenId] = creator;

        return tokenId;
    }
}
