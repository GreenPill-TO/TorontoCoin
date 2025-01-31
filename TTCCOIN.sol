// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TTC is ERC20, AccessControl, Pausable, Ownable {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public totalMinted;
    uint256 public totalBurned;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor() ERC20("TTC Token", "TTC") Ownable() {
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    // Mint new tokens
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
        totalMinted += amount;
        emit Minted(to, amount);
    }

    // Burn tokens from sender's account
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
        totalBurned += amount;
        emit Burned(msg.sender, amount);
    }

    // Pause contract
    function pause() external onlyRole(OWNER_ROLE) {
        _pause();
    }

    // Unpause contract
    function unpause() external onlyRole(OWNER_ROLE) {
        _unpause();
    }

    // View total minted tokens
    function getTotalMinted() external view returns (uint256) {
        return totalMinted;
    }

    // View total burned tokens
    function getTotalBurned() external view returns (uint256) {
        return totalBurned;
    }

    // View current circulating supply
    function getTotalTTCSupply() external view returns (uint256) {
        return totalSupply();
    }

    // Transfer ownership
    function transferOwnership(address newOwner) public override onlyRole(OWNER_ROLE) {
        _transferOwnership(newOwner);
    }

    // Assign MINTER_ROLE to another address
    function grantMinterRole(address account) external onlyRole(OWNER_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    // Remove MINTER_ROLE from an address
    function revokeMinterRole(address account) external onlyRole(OWNER_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }
}
