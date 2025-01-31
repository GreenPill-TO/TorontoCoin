// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TTC is ERC20, AccessControl, Pausable {
    using Counters for Counters.Counter;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _totalBurned; // Tracks total burned tokens

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor() ERC20("TTC Token", "TTC") {
        _grantRole(OWNER_ROLE, msg.sender); // Owner role assigned
        _grantRole(MINTER_ROLE, msg.sender); // Minter role assigned
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE); // Makes OWNER_ROLE its own admin
        _setRoleAdmin(MINTER_ROLE, OWNER_ROLE); // Makes OWNER_ROLE admin for the MINTER_ROLE
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
        _totalBurned.increment();
        emit Burned(msg.sender, amount);
    }

    function pause() external onlyRole(OWNER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OWNER_ROLE) {
        _unpause();
    }

    function getTotalMinted() external view returns (uint256) {
        return totalSupply() + _totalBurned.current();
    }

    function getTotalBurned() external view returns (uint256) {
        return _totalBurned.current();
    }
}
