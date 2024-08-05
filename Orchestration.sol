// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TCOIN.sol";
import "./TTCCOIN.sol";

contract Orchestrator is Ownable {
    TCOIN private tcoin;
    TTC private ttc;
    address private charityAddress; // Address to send the excess amount

    constructor(address _tcoinAddress, address _ttcAddress, address _charityAddress) Ownable(msg.sender) {
        tcoin = TCOIN(_tcoinAddress);
        ttc = TTC(_ttcAddress);
        charityAddress = _charityAddress;
    }

    // Function to calculate the reserve ratio
    function calculateReserveRatio() public view returns (uint256) {
        uint256 totalTCOIN = tcoin.getTotalTCOINSupply();
        uint256 totalRawSupply = tcoin.getTotalRawSupply();
        require(totalRawSupply > 0, "Total raw supply must be greater than 0");

        // Calculate reserve ratio as a percentage with 4 decimal places
        return (totalTCOIN * 1000000) / totalRawSupply;
    }

    // Function to rebase the TCOIN contract
    function rebaseTCOIN() external onlyOwner {
        tcoin.rebase();
    }

    // Function to update demurrage rate
    function updateDemurrageRate(uint256 newDemurrageRate) external onlyOwner {
        tcoin.updateDemurrageRate(newDemurrageRate);
    }

    // Function to update rebase period
    function updateRebasePeriod(uint256 newRebasePeriod) external onlyOwner {
        tcoin.updateRebasePeriod(newRebasePeriod);
    }

    // Function to redeem TCOIN for TTC based on reserve ratio
    function redeemTCOIN(uint256 tcoinAmount) external {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");

        uint256 reserveRatio = calculateReserveRatio();
        uint256 ttcAmount = (tcoinAmount * reserveRatio) / 10000;

        // If reserve ratio is less than 0.8, give user 5% less TTC tokens
        if (reserveRatio < 800000) {
            ttcAmount = ttcAmount * 95 / 100;
        }

        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > 1200000) {
            uint256 excessAmount = (tcoinAmount * (reserveRatio - 1200000)) / 10000;
            ttc.mint(charityAddress, excessAmount);
            ttcAmount = (tcoinAmount * 1200000) / 10000;
        }

        // Burn the TCOIN directly from the user's balance
        tcoin.burn(msg.sender, tcoinAmount);

        // Mint TTC to the contract
        ttc.mint(address(this), ttcAmount);

        // Transfer TTC to the user
        ttc.transfer(msg.sender, ttcAmount);
    }
}
