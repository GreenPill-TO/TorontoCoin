// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TCOIN.sol";
import "./TTCCOIN.sol";

contract Orchestrator is Ownable {
    TCOIN private tcoin;
    TTC private ttc;

    constructor(address _tcoinAddress, address _ttcAddress) Ownable(msg.sender) {
        tcoin = TCOIN(_tcoinAddress);
        ttc = TTC(_ttcAddress);
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

        // Burn the TCOIN directly from the user's balance
        tcoin.burn(msg.sender, tcoinAmount);
        // Mint TTC to the contract
        ttc.mint(address(this), ttcAmount);
        // Transfer TTC COIN to the user
        ttc.transfer(msg.sender, ttcAmount);
    }
}
