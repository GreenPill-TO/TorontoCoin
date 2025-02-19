// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MyToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(string memory name, string memory symbol, address admin)
        ERC20(name, symbol)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function mint(address to, uint256 amount) public nonReentrant onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function pause() public nonReentrant onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public nonReentrant onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Pausable)
        whenNotPaused
    {
        super._update(from, to, amount);
    }
}
