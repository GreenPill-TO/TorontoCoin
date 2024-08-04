// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TTC is ERC20, Ownable (msg.sender) {
    uint256 public totalMinted;
    uint256 public totalBurned;
    uint256 public totalTTCSupply;

    constructor() ERC20("TTCToken", "TTC") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        totalMinted += amount;

        // Update Total Supply
        if (totalMinted > 0) {
            totalTTCSupply = totalMinted - totalBurned; 
        }
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
        totalBurned += amount;

        // Update Total Supply
        if (totalBurned > 0) {
            totalTTCSupply = totalMinted - totalBurned; 
        }
    }

    function getTotalMinted() external view returns (uint256) {
        return totalMinted;
    }

    function getTotalBurned() external view returns (uint256) {
        return totalBurned;
    }

    function getTotalTTCCOINSupply() external view returns (uint256) {
        if (totalTTCSupply != 0) {
            return totalTTCSupply;
        }
        else{
            return 0;
        }
    }
}
