// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CAD is ERC20, AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _totalBurned; // Tracks total burned tokens

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    // Initialize the contract
    constructor() ERC20("CAD Token", "CAD") {
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    // Mint new tokens
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    // Burn tokens from sender's account
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
        _totalBurned.increment();
        emit Burned(msg.sender, amount);
    }

    // View total minted tokens (calculated dynamically)
    function getTotalMinted() external view returns (uint256) {
        return totalSupply() + _totalBurned.current();
    }

    // View total burned tokens
    function getTotalBurned() external view returns (uint256) {
        return _totalBurned.current();
    }
}
