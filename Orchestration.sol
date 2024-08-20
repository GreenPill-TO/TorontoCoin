// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TCOIN.sol";
import "./TTCCOIN.sol";
import "./CADCOIN.sol";
import "./Voting.sol";

contract Orchestrator is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    TCOIN private tcoin;
    TTC private ttc;
    CAD private cad;
    Voting public voting;
    address private charityAddress; // Address to send the excess amount over 1.2 reserve ratio and default charity address
    address private reserveTokensAddress; // Address to send tokens after user redeem their TCOIN's
    uint256 public pegValue = voting.getPegValue(); // Representing $3.3 with 2 decimal places
    uint256 public stewardCount; // Total number of stewards
    uint256 public redemptionRateUserTTC = voting.getRedemptionRateUserTTC();
    uint256 public redemptionRateStoreTTC = voting.getRedemptionRateStoreTTC();
    uint256 public redemptionRateUserCAD = voting.getRedemptionRateUserCAD();
    uint256 public redemptionRateStoreCAD = voting.getRedemptionRateStoreCAD();
    uint256 public minimumReserveRatio = voting.getMinimumReserveRatio();
    uint256 public maximumReserveRatio = voting.getMaximumReserveRatio();
    uint256 public demurrageRate = voting.getDemurrageRate();
    uint256 public reserveRatio = voting.getReserveRatio();

    // Mappings for charity names and addresses
    mapping(uint256 => string) public charityNames;
    mapping(uint256 => address) public charityAddresses;
    mapping(address => bool) public isCharityAddress;
    mapping(address => uint256) public charityTotalMintable; // Tracks the total mintable for each charity
    mapping(uint256 => Steward) public stewards; // Mapping for stewards

    function setTcoinAddress(address _tcoinAddress) external onlyOwner {
        tcoin = TCOIN(_tcoinAddress);
    }

    function setTtcAddress(address _ttcAddress) external onlyOwner {
        ttc = TTC(_ttcAddress);
    }

    function setCadAddress(address _cadAddress) external onlyOwner {
        cad = CAD(_cadAddress);
    }   

    // Struct to represent a steward
    struct Steward {
        uint256 id;
        string name;
        address stewardAddress;
    }

    function initialize(
        address _tcoinAddress,
        address _ttcAddress,
        address _cadAddress,
        address _charityAddress,
        address _reserveTokensAddress,
        address _votingAddress
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        tcoin = TCOIN(_tcoinAddress);
        ttc = TTC(_ttcAddress);
        cad = CAD(_cadAddress);
        voting = Voting(_votingAddress);
        charityAddress = _charityAddress;
        reserveTokensAddress = _reserveTokensAddress;
        pegValue = 330; // Representing $3.3 with 2 decimal places
        stewardCount = 0; // Total number of stewards
        redemptionRateUserTTC = 92;
        redemptionRateStoreTTC = 95;
        redemptionRateUserCAD = 87;
        redemptionRateStoreCAD = 90;
        minimumReserveRatio = 800000;
        maximumReserveRatio = 1200000;
        demurrageRate = tcoin.getDemurrageRate();
        reserveRatio = calculateReserveRatio();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getPegValue() external returns (uint256) {
        return pegValue;
    }

    function getStewardCount() external returns (uint256) {
        return stewardCount;
    }

    function getRedemptionRateUserTTC() external returns (uint256) {
        return redemptionRateUserTTC;
    }

    function getRedemptionRateStoreTTC() external returns (uint256) {
        return redemptionRateStoreTTC;
    }

    function getRedemptionRateUserCAD() external returns (uint256) {
        return redemptionRateUserCAD;
    }

    function getRedemptionRateStoreCAD() external returns (uint256) {
        return redemptionRateStoreCAD;
    }

    function getMinimumReserveRatio() external returns (uint256) {
        return minimumReserveRatio;
    }

    function getMaximumReserveRatio() external returns (uint256) {
        return maximumReserveRatio;
    }

    function getDemurrageRate() external returns (uint256) {
        return redemptionRateUserCAD;
    }

    function getReserveRatio() external returns (uint256) {
        return reserveRatio;
    }

    // Function to add new charity with a name and address
    function addCharity(uint256 id, string memory name, address charity) external onlyOwner {
        charityNames[id] = name;
        charityAddresses[id] = charity;
        isCharityAddress[charityAddress] = true;
    }

    // Function to check if an address is a charity
    function isCharity(address _charity) external view returns (bool) {
        return isCharityAddress[_charity];
    }

    // Function to nominate a steward by a charity
    function nominateSteward(uint256 stewardId, string memory name, address stewardAddress) external {
        address charity = msg.sender;
        require(charityTotalMintable[charity] > 0, "Charity has no mintable amount");

        stewards[stewardId] = Steward({
            id: stewardId,
            name: name,
            stewardAddress: stewardAddress
        });
        stewardCount++;
    }

    // Function to check if an address is a steward
    function isSteward(address addr) external view returns (bool) {
        for (uint256 i = 0; i < stewardCount; i++) {
            if (stewards[i].stewardAddress == addr) {
                return true;
            }
        }
        return false;
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

    // Redeem function where user doesn't select charity and charity with index 0 is used by default
    function redeemTCOINForUserTTCCOIN(uint256 tcoinAmount) public {
        redeemTCOINForUserTTCCOIN(tcoinAmount, 0);
    }

    // Function to redeem TCOIN for TTC to get 100% value
    function redeemTCOINTTCCOIN(uint256 tcoinAmount, uint256 charityId) public {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        reserveRatio = calculateReserveRatio();
        uint256 ttcAmount = (tcoinAmount * reserveRatio) / 10000;

        // Give the user 100% value of TCOIN in TTC coin
        ttcAmount = ttcAmount;

        // If reserve ratio is less than 0.8, give user 5% less TTC tokens
        if (reserveRatio < minimumReserveRatio) {
            ttcAmount = ttcAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > maximumReserveRatio) {
            excessAmount = (tcoinAmount * (reserveRatio - maximumReserveRatio)) / 10000;
            ttc.mint(charityAddress, excessAmount);
            ttcAmount = (tcoinAmount * maximumReserveRatio) / 10000;
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

    // Function to redeem TCOIN for CAD to get 100% value
    function redeemTCOINFCADCOIN(uint256 tcoinAmount, uint256 charityId) public {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        reserveRatio = calculateReserveRatio();
        uint256 cadAmount = (tcoinAmount * reserveRatio * pegValue) / 1000000;

        // Give the user 100% value of TCOIN in CAD coin
        cadAmount = cadAmount;

        // If reserve ratio is less than 0.8, give user 5% less CAD tokens
        if (reserveRatio < minimumReserveRatio) {
            cadAmount = cadAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > maximumReserveRatio) {
            excessAmount = (cadAmount * (reserveRatio - maximumReserveRatio)) / 10000;
            cad.mint(charityAddress, excessAmount);
            cadAmount = (tcoinAmount * pegValue * maximumReserveRatio) / 10000;
        }

        // Burn the 5% overhead of TCOIN
        uint256 burnAmount = (tcoinAmount * 5) / 100;
        tcoin.burn(msg.sender, burnAmount);
        // Send 95% of TCOIN value to reserve
        uint256 reserveAmount = (tcoinAmount * 95) / 100;
        tcoin.transfer(reserveTokensAddress, reserveAmount);
        // Mint CAD to the contract
        cad.mint(address(this), cadAmount);
        // Transfer CAD to the user
        cad.transfer(msg.sender, cadAmount);
        // Update total mintable for the chosen charity by the TCOIN amount excluding excess amount
        charityTotalMintable[charityAddresses[charityId]] += (tcoinAmount - excessAmount);
    }

    // Function to redeem TCOIN for TTC based on reserve ratio
    function redeemTCOINForUserTTCCOIN(uint256 tcoinAmount, uint256 charityId) public {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        reserveRatio = calculateReserveRatio();
        uint256 ttcAmount = (tcoinAmount * reserveRatio) / 10000;

        // Give the user 95% value of TCOIN in TTC coin
        ttcAmount = ttcAmount * redemptionRateUserTTC / 100;

        // If reserve ratio is less than 0.8, give user 5% less TTC tokens
        if (reserveRatio < minimumReserveRatio) {
            ttcAmount = ttcAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > maximumReserveRatio) {
            excessAmount = (tcoinAmount * (reserveRatio - maximumReserveRatio)) / 10000;
            ttc.mint(charityAddress, excessAmount);
            ttcAmount = (tcoinAmount * maximumReserveRatio) / 10000;
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

    // Redeem function where store doesn't select charity and charity with index 0 is used by default
    function redeemTCOINForStoreTTCCOIN(uint256 tcoinAmount) public {
        redeemTCOINForStoreTTCCOIN(tcoinAmount, 0);
    }

    // Function to redeem TCOIN for TTC based on reserve ratio
    function redeemTCOINForStoreTTCCOIN(uint256 tcoinAmount, uint256 charityId) public {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        reserveRatio = calculateReserveRatio();
        uint256 ttcAmount = (tcoinAmount * reserveRatio) / 10000;

        // Give the user 95% value of TCOIN in TTC coin
        ttcAmount = ttcAmount * redemptionRateStoreTTC / 100;

        // If reserve ratio is less than 0.8, give user 5% less TTC tokens
        if (reserveRatio < minimumReserveRatio) {
            ttcAmount = ttcAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > maximumReserveRatio) {
            excessAmount = (tcoinAmount * (reserveRatio - maximumReserveRatio)) / 10000;
            ttc.mint(charityAddress, excessAmount);
            ttcAmount = (tcoinAmount * maximumReserveRatio) / 10000;
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

     // Redeem function where user doesn't select charity and charity with index 0 is used by default
    function redeemTCOINForUserCADCOIN(uint256 tcoinAmount) public {
        redeemTCOINForUserCADCOIN(tcoinAmount, 0);
    }

    // Function to redeem TCOIN for CAD based on reserve ratio
    function redeemTCOINForUserCADCOIN(uint256 tcoinAmount, uint256 charityId) public {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        reserveRatio = calculateReserveRatio();
        uint256 cadAmount = (tcoinAmount * reserveRatio * pegValue) / 1000000;

        // Give the user 90% value of TCOIN in CAD coin
        cadAmount = cadAmount * redemptionRateUserCAD / 100;

        // If reserve ratio is less than 0.8, give user 5% less CAD tokens
        if (reserveRatio < minimumReserveRatio) {
            cadAmount = cadAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > maximumReserveRatio) {
            excessAmount = (cadAmount * (reserveRatio - maximumReserveRatio)) / 10000;
            cad.mint(charityAddress, excessAmount);
            cadAmount = (tcoinAmount * pegValue * maximumReserveRatio) / 10000;
        }

        // Burn the 5% overhead of TCOIN
        uint256 burnAmount = (tcoinAmount * 5) / 100;
        tcoin.burn(msg.sender, burnAmount);
        // Send 95% of TCOIN value to reserve
        uint256 reserveAmount = (tcoinAmount * 95) / 100;
        tcoin.transfer(reserveTokensAddress, reserveAmount);
        // Mint CAD to the contract
        cad.mint(address(this), cadAmount);
        // Transfer CAD to the user
        cad.transfer(msg.sender, cadAmount);
        // Update total mintable for the chosen charity by the TCOIN amount excluding excess amount
        charityTotalMintable[charityAddresses[charityId]] += (tcoinAmount - excessAmount);
    }

    // Redeem function where store doesn't select charity and charity with index 0 is used by default
    function redeemTCOINForStoreCADCOIN(uint256 tcoinAmount) public {
        redeemTCOINForStoreCADCOIN(tcoinAmount, 0);
    }

    // Function to redeem TCOIN for CAD based on reserve ratio
    function redeemTCOINForStoreCADCOIN(uint256 tcoinAmount, uint256 charityId) public {
        require(tcoin.balanceOf(msg.sender) >= tcoinAmount, "Insufficient TCOIN balance");
        require(charityAddresses[charityId] != address(0), "This charity doesn't exist");

        reserveRatio = calculateReserveRatio();
        uint256 cadAmount = (tcoinAmount * reserveRatio * pegValue) / 1000000;

        // Give the user 90% value of TCOIN in CAD coin
        cadAmount = cadAmount * redemptionRateStoreCAD / 100;

        // If reserve ratio is less than 0.8, give user 5% less CAD tokens
        if (reserveRatio < minimumReserveRatio) {
            cadAmount = cadAmount * 95 / 100;
        }

        uint256 excessAmount = 0;
        // If reserve ratio is greater than 1.2, send amount over 1.2 to charity
        if (reserveRatio > maximumReserveRatio) {
            excessAmount = (tcoinAmount * (reserveRatio - maximumReserveRatio)) / 10000;
            cad.mint(charityAddress, excessAmount);
            cadAmount = (tcoinAmount * pegValue * maximumReserveRatio) / 10000;
        }

        // Burn the TCOIN directly from the user's balance
        tcoin.burn(msg.sender, tcoinAmount);
        // Mint CAD to the contract
        ttc.mint(address(this), cadAmount);
        // Transfer CAD to the user
        ttc.transfer(msg.sender, cadAmount);
        // Update total mintable for the chosen charity by the TCOIN amount excluding excess amount
        charityTotalMintable[charityAddresses[charityId]] += (tcoinAmount - excessAmount);
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
