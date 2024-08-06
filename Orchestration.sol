// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TCOIN.sol";
import "./TTCCOIN.sol";

contract Orchestrator is Ownable {
    TCOIN private tcoin;
    TTC private ttc;
    address private charityAddress; // Address to send the excess amount over 1.2 reserve ratio
    address private reserveTokensAddress; // Address to send tokens after user redeem their TCOIN's

    // Mappings for charity names and addresses
    mapping(uint256 => string) public charityNames;
    mapping(uint256 => address) public charityAddresses;
    mapping(address => uint256) public charityTotalMintable; // Tracks the total mintable for each charity

    constructor(address _tcoinAddress, address _ttcAddress, address _charityAddress, address _reserveTokensAddress) Ownable(msg.sender) {
        tcoin = TCOIN(_tcoinAddress);
        ttc = TTC(_ttcAddress);
        charityAddress = _charityAddress;
        reserveTokensAddress = _reserveTokensAddress;
    }

    // Function to add new charity with a name and address
    function addCharity(uint256 id, string memory name, address charity) external onlyOwner {
        charityNames[id] = name;
        charityAddresses[id] = charity;
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
    function redeemTCOINForUser(uint256 tcoinAmount, uint256 charityId) external {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        uint256 reserveRatio = calculateReserveRatio();
        uint256 ttcAmount = (tcoinAmount * reserveRatio) / 10000;

        // Give the user 95% value of TCOIN in TTC coin, overhead will allow charities to redeem at 100% value 
        ttcAmount = ttcAmount * 95 / 100;

        // If reserve ratio is less than 0.8, give user 5% less TTC tokens
        if (reserveRatio < 800000) {
            ttcAmount = ttcAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > 1200000) {
            excessAmount = (tcoinAmount * (reserveRatio - 1200000)) / 10000;
            ttc.mint(charityAddress, excessAmount);
            ttcAmount = (tcoinAmount * 1200000) / 10000;
        }

        // Burn the 5% overhead of TCOIN
        uint256 burnAmount = (tcoinAmount * 5) / 100;
        tcoin.burn(msg.sender, burnAmount);
        // Send 95% of TCOIN value to reserve
        uint256 reserveAmount = (tcoinAmount * 95) / 100;
        tcoin.transfer(reserveTokensAddress, reserveAmount);
        // Mint TTC to the contract
        ttc.mint(address(this), ttcAmount);
        // Transfer TTC to the user
        ttc.transfer(msg.sender, ttcAmount);
        // Update total mintable for the chosen charity by the TCOIN amount excluding excess amount
        charityTotalMintable[charityAddresses[charityId]] += (tcoinAmount - excessAmount);
    }

    // Function to redeem TCOIN for TTC based on reserve ratio
    function redeemTCOINForStore(uint256 tcoinAmount, uint256 charityId) external {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        uint256 reserveRatio = calculateReserveRatio();
        uint256 ttcAmount = (tcoinAmount * reserveRatio) / 10000;

        // Give the user 95% value of TCOIN in TTC coin, overhead will allow charities to redeem at 100% value 
        ttcAmount = ttcAmount * 95 / 100;

        // If reserve ratio is less than 0.8, give user 5% less TTC tokens
        if (reserveRatio < 800000) {
            ttcAmount = ttcAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > 1200000) {
            excessAmount = (tcoinAmount * (reserveRatio - 1200000)) / 10000;
            ttc.mint(charityAddress, excessAmount);
            ttcAmount = (tcoinAmount * 1200000) / 10000;
        }

        // Burn the TCOIN directly from the user's balance
        tcoin.burn(msg.sender, tcoinAmount);
        // Mint TTC to the contract
        ttc.mint(address(this), ttcAmount);
        // Transfer TTC to the user
        ttc.transfer(msg.sender, ttcAmount);
        // Update total mintable for the chosen charity by the TCOIN amount excluding excess amount
        charityTotalMintable[charityAddresses[charityId]] += (tcoinAmount - excessAmount);
    }

    // Function to redeem TCOIN for TTC based on reserve ratio
    function redeemTCOINForCharity(uint256 tcoinAmount) external {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");

        uint256 reserveRatio = calculateReserveRatio();
        uint256 ttcAmount = (tcoinAmount * reserveRatio) / 10000; // Give the charity 100% value of TCOIN

        // If reserve ratio is less than 0.8, give user 5% less TTC tokens
        if (reserveRatio < 800000) {
            ttcAmount = ttcAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > 1200000) {
            excessAmount = (tcoinAmount * (reserveRatio - 1200000)) / 10000;
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

    // Function for charities to mint TCOIN
    function mintTCOINForCharity(uint256 tcoinAmount) external {
        address charity = msg.sender;
        require(charityTotalMintable[charity] >= tcoinAmount, "Insufficient mintable amount");

        // Mint TCOIN to the charity
        tcoin.mint(charity, tcoinAmount);

        // Reduce total mintable amount for the charity
        charityTotalMintable[charity] -= tcoinAmount;
    }
}
