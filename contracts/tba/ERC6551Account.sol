// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/token/ERC721/IERC721.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/token/ERC20/IERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/interfaces/IERC1271.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/utils/cryptography/SignatureChecker.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/token/ERC1155/IERC1155Receiver.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/utils/introspection/IERC165.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IERC6551Account.sol";

import "./lib/MinimalReceiver.sol";
import "./lib/ERC6551AccountLib.sol";

contract ERC6551Account is IERC165, IERC1271, IERC6551Account, IERC721Receiver {
    uint256 public nonce;

    // Events
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    receive() external payable {}

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        require(msg.sender == owner(), "Not token owner");
        require(to != address(0), "Invalid target address");
        require(to != address(this), "Cannot call self");
        
        // Prevent common dangerous operations
        if (data.length >= 4) {
            bytes4 selector;
            assembly {
                selector := calldataload(data.offset)
            }
            // Prevent selfdestruct
            require(selector != 0xff000000, "Selfdestruct not allowed");
            // Prevent delegatecall to preserve account integrity
            require(selector != 0xd4d9bdcd, "Delegatecall not allowed");
        }

        ++nonce;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token() external view returns (uint256, address, uint256) {
        return ERC6551AccountLib.token();
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId);
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue) {
        bool isValid = SignatureChecker.isValidSignatureNow(
            owner(),
            hash,
            signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
