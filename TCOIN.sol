// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TCOIN is ERC20, Ownable {
    // State variables
    string private tokenName = "TorontoCoin";
    string private tokenSymbol = "TCOIN";
    uint256 private _decimals = 18;
    uint256 private totalTCOINSupply; // TCoin supply including demurrage rate
    uint256 private totalMintedSupply; // Track total minted 
    uint256 private totalBurned; // Track total burned 
    uint256 private totalRawSupply; // Tracks how much tokens should exist without demurrage rate
    uint256 private lastRebaseTime;
    uint256 private REBASE_PERIOD = 86400; // 1 day in seconds
    uint256 private DEMURRAGE_RATE = 99967; // (1 - 0.0333% daily reduction) * 100000
    address private orchestrator;

    mapping(address => bool) private whitelistedStores;
    address[] private allTokenHolders;

    // Modifiers
    modifier onlyOrchestrator() {
        require(msg.sender == orchestrator, "Caller is not the orchestrator!");
        _;
    }

    modifier onlyWhitelistedStore() {
        require(whitelistedStores[msg.sender], "Caller is not a whitelisted store!");
        _;
    }

    // Events
    event Rebase(uint256 newTotalSupply);
    event OrchestratorUpdated(address newOrchestrator);
    event StoreWhitelisted(address store);
    event StoreRemovedFromWhitelist(address store);
    event DemurrageRateUpdated(uint256 newDemurrageRate);
    event RebasePeriodUpdated(uint256 newRebasePeriod);
    event Minted(address to, uint256 amount); // Event for minting

    constructor() ERC20("TorontoCoin", "TCOIN") Ownable(msg.sender) {
        lastRebaseTime = block.timestamp;
    }

    // Rebase function
    function rebase() public {
        require(block.timestamp >= lastRebaseTime + REBASE_PERIOD, "Rebase: Too early to rebase");

        uint256 newTotalSupply = totalTCOINSupply * DEMURRAGE_RATE / 100000;
        totalTCOINSupply = newTotalSupply;

        emit Rebase(newTotalSupply);
        lastRebaseTime = block.timestamp;
    }

    function _updateTokenHolderList(address account) internal {
        if (ERC20.balanceOf(account) == 0) { // Use ERC20.balanceOf to avoid infinite recursion
            // Remove account from allTokenHolders if balance is zero
            for (uint256 i = 0; i < allTokenHolders.length; i++) {
                if (allTokenHolders[i] == account) {
                    allTokenHolders[i] = allTokenHolders[allTokenHolders.length - 1];
                    allTokenHolders.pop();
                    break;
                }
            }
        } else {
            // Add account to allTokenHolders if not already present
            bool alreadyHolder = false;
            for (uint256 i = 0; i < allTokenHolders.length; i++) {
                if (allTokenHolders[i] == account) {
                    alreadyHolder = true;
                    break;
                }
            }
            if (!alreadyHolder) {
                allTokenHolders.push(account);
            }
        }
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _mint(address(this), amount); // Mint new tokens to the smart contract address
        _transfer(address(this), recipient, amount); // Transfer tokens from the smart contract to the recipient
        _updateTokenHolderList(msg.sender); // Update token holder list
        _updateTokenHolderList(recipient);

        return true;
    }

    function mint(address to, uint256 amount) public onlyWhitelistedStore {
        _mint(to, amount);
        totalTCOINSupply += amount;
        totalMintedSupply += amount; // Update the total minted supply
        _updateTokenHolderList(to);
        emit Minted(to, amount); // Emit event for minting

        // Update Total Supply
        if (totalMintedSupply > 0) {
            totalRawSupply = totalMintedSupply - totalBurned; 
        }
    }

    function burn(address from, uint256 amount) public onlyWhitelistedStore {
        _burn(from, amount);
        totalTCOINSupply -= amount;
        totalBurned += amount; // Update the total burned supply to reflect burning tokens
        _updateTokenHolderList(from);

        // Update Total Supply
        if (totalBurned > 0) {
            totalRawSupply = totalMintedSupply - totalBurned; 
        }
    }

    // Functions to update demurrage rate and rebase period
    function updateDemurrageRate(uint256 newDemurrageRate) external onlyOwner {
        require(newDemurrageRate > 0, "Demurrage rate must be greater than 0");
        DEMURRAGE_RATE = newDemurrageRate;
        emit DemurrageRateUpdated(newDemurrageRate);
    }

    function updateRebasePeriod(uint256 newRebasePeriod) external onlyOwner {
        require(newRebasePeriod > 0, "Rebase period must be greater than 0");
        REBASE_PERIOD = newRebasePeriod;
        emit RebasePeriodUpdated(newRebasePeriod);
    }

    // Whitelisting functions
    function setOrchestrator(address _orchestrator) external onlyOwner {
        orchestrator = _orchestrator;
        emit OrchestratorUpdated(_orchestrator);
    }

    function whitelistStore(address store) external onlyOrchestrator {
        whitelistedStores[store] = true;
        emit StoreWhitelisted(store);
    }

    function removeStoreFromWhitelist(address store) external onlyOrchestrator {
        whitelistedStores[store] = false;
        emit StoreRemovedFromWhitelist(store);
    }

    // Modified ERC20 functions
    function totalSupply() public view override returns (uint256) {
        return totalTCOINSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return ERC20.balanceOf(account);
    }

    // Get totalRawSupply
    function getTotalRawSupply() external view returns (uint256) {
        return totalRawSupply;
    }

    // Get totalTCOINSupply
    function getTotalTCOINSupply() external view returns (uint256) {
        return totalTCOINSupply;
    }
}
