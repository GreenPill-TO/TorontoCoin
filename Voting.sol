// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Orchestration.sol";

contract Voting is Initializable, OwnableUpgradeable {
    Orchestrator public orchestrator;

    uint256 public pegValue;
    uint256 public stewardCount;
    uint256 public redemptionRateUserTTC;
    uint256 public redemptionRateStoreTTC;
    uint256 public redemptionRateUserCAD;
    uint256 public redemptionRateStoreCAD;
    uint256 public minimumReserveRatio;
    uint256 public maximumReserveRatio;
    uint256 public demurrageRate;
    uint256 public reserveRatio;

    enum VoteOption { Increment, Decrement, Leave }

    struct Vote {
        uint256 incrementVotes;
        uint256 decrementVotes;
        uint256 leaveVotes;
        uint256 totalVotes;
    }

    mapping(uint256 => uint256) public pegValueVoteCounts; // Tracks the number of votes for each proposed value
    mapping(address => bool) public hasVoted; // Tracks whether a steward has voted
    mapping(address => uint256) public stewardVotes; // Tracks the current vote of each steward
    uint256[] public proposedPegValues; // List of proposed peg values
    mapping(string => Vote) public votes; // Track votes for parameters
    mapping(address => mapping(string => VoteOption)) public stewardVotesAll; // Track steward votes for remaining values


    modifier onlySteward() {
        require(orchestrator.isSteward(msg.sender), "Only stewards can vote");
        _;
    }

    function initialize(address _orchestrator) public initializer {
        __Ownable_init(msg.sender);
        orchestrator = Orchestrator(_orchestrator);
        pegValue = orchestrator.getPegValue();
        stewardCount = orchestrator.getStewardCount();
        redemptionRateUserTTC = orchestrator.getRedemptionRateUserTTC();
        redemptionRateStoreTTC = orchestrator.getRedemptionRateStoreTTC();
        redemptionRateUserCAD = orchestrator.getRedemptionRateUserCAD();
        redemptionRateStoreCAD = orchestrator.getRedemptionRateStoreCAD();
        minimumReserveRatio = orchestrator.getMinimumReserveRatio();
        maximumReserveRatio = orchestrator.getMaximumReserveRatio();
        demurrageRate = orchestrator.getDemurrageRate();
        reserveRatio = orchestrator.getReserveRatio();
    }

    function getPegValue() external returns (uint256) {
        return pegValue;
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

    // Function to vote for updating the peg value
    function voteToUpdatePegValue(uint256 proposedPegValue) external {
        address steward = msg.sender;
        require(orchestrator.isSteward(steward), "Only stewards can vote");

        // Check if the steward has voted before and decrease the vote count for the previous value
        if (hasVoted[steward]) {
            uint256 previousVote = stewardVotes[steward];
            pegValueVoteCounts[previousVote]--;
        } else {
            hasVoted[steward] = true;
        }

        // Update the steward's vote
        stewardVotes[steward] = proposedPegValue;
        pegValueVoteCounts[proposedPegValue]++;

        // Check if the proposed value has the highest vote count
        uint256 highestVoteCount = 0;
        uint256 leadingPegValue = pegValue;

        for (uint256 i = 0; i < proposedPegValues.length; i++) {
            uint256 currentPegValue = proposedPegValues[i];
            uint256 currentVoteCount = pegValueVoteCounts[currentPegValue];

            if (currentVoteCount > highestVoteCount) {
                highestVoteCount = currentVoteCount;
                leadingPegValue = currentPegValue;
            } else if (currentVoteCount == highestVoteCount && currentPegValue != leadingPegValue) {
                // If there is a tie, do not update the peg value
                leadingPegValue = pegValue;
            }
        }

        // Update the peg value if there is a clear leader
        if (leadingPegValue != pegValue) {
            pegValue = leadingPegValue;
        }
    }

    // Function to vote for multiple parameters
    function voteToUpdateValues(
        VoteOption voteOptionRedemptionRateUserTTC,
        VoteOption voteOptionRedemptionRateStoreTTC,
        VoteOption voteOptionRedemptionRateUserCAD,
        VoteOption voteOptionRedemptionRateStoreCAD,
        VoteOption voteOptionMinimumReserveRatio,
        VoteOption voteOptionMaximumReserveRatio,
        VoteOption voteOptionDemurrageRate,
        VoteOption voteOptionReserveRatio
    ) external {
        address steward = msg.sender;
        require(orchestrator.isSteward(steward), "Only stewards can vote");

        // Check if the steward has voted before and decrement the vote count for the previous value
        if (hasVoted[steward]) {
            resetVotesForSteward(steward);
        } else {
            hasVoted[steward] = true;
        }

        // Update steward's votes
        stewardVotesAll[steward]["redemptionRateUserTTC"] = voteOptionRedemptionRateUserTTC;
        stewardVotesAll[steward]["redemptionRateStoreTTC"] = voteOptionRedemptionRateStoreTTC;
        stewardVotesAll[steward]["redemptionRateUserCAD"] = voteOptionRedemptionRateUserCAD;
        stewardVotesAll[steward]["redemptionRateStoreCAD"] = voteOptionRedemptionRateStoreCAD;
        stewardVotesAll[steward]["minimumReserveRatio"] = voteOptionMinimumReserveRatio;
        stewardVotesAll[steward]["maximumReserveRatio"] = voteOptionMaximumReserveRatio;
        stewardVotesAll[steward]["demurrageRate"] = voteOptionDemurrageRate;
        stewardVotesAll[steward]["reserveRatio"] = voteOptionReserveRatio;

        // Process votes
        processVote("redemptionRateUserTTC", voteOptionRedemptionRateUserTTC);
        processVote("redemptionRateStoreTTC", voteOptionRedemptionRateStoreTTC);
        processVote("redemptionRateUserCAD", voteOptionRedemptionRateUserCAD);
        processVote("redemptionRateStoreCAD", voteOptionRedemptionRateStoreCAD);
        processVote("minimumReserveRatio", voteOptionMinimumReserveRatio);
        processVote("maximumReserveRatio", voteOptionMaximumReserveRatio);
        processVote("demurrageRate", voteOptionDemurrageRate);
        processVote("reserveRatio", voteOptionReserveRatio);

        // Check and update values if necessary
        checkAndUpdateValues("redemptionRateUserTTC");
        checkAndUpdateValues("redemptionRateStoreTTC");
        checkAndUpdateValues("redemptionRateUserCAD");
        checkAndUpdateValues("redemptionRateStoreCAD");
        checkAndUpdateValues("minimumReserveRatio");
        checkAndUpdateValues("maximumReserveRatio");
        checkAndUpdateValues("demurrageRate");
        checkAndUpdateValues("reserveRatio");
    }

    function processVote(string memory valueName, VoteOption voteOption) internal {
        if (voteOption == VoteOption.Increment) {
            votes[valueName].incrementVotes++;
        } else if (voteOption == VoteOption.Decrement) {
            votes[valueName].decrementVotes++;
        } else if (voteOption == VoteOption.Leave) {
            votes[valueName].leaveVotes++;
        }
        votes[valueName].totalVotes++;
    }

    function checkAndUpdateValues(string memory valueName) internal {
        if (votes[valueName].totalVotes * 2 >= stewardCount) { // 50% or more votes
                VoteOption winningOption = getWinningOption(valueName);
                updateValue(valueName, winningOption);
            resetVotes(valueName);
        }
    }

    function updateValue(string memory valueName, VoteOption winningOption) internal {
        if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("redemptionRateUserTTC"))) {
            if (winningOption == VoteOption.Increment) {
                redemptionRateUserTTC = redemptionRateUserTTC * 101 / 100; // Increment by 1%
            } else if (winningOption == VoteOption.Decrement) {
                redemptionRateUserTTC = redemptionRateUserTTC * 99 / 100; // Decrement by 1%
            }
        } else if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("redemptionRateStoreTTC"))) {
            if (winningOption == VoteOption.Increment) {
                redemptionRateStoreTTC = redemptionRateStoreTTC * 101 / 100; // Increment by 1%
            } else if (winningOption == VoteOption.Decrement) {
                redemptionRateStoreTTC = redemptionRateStoreTTC * 99 / 100; // Decrement by 1%
            }
        } else if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("redemptionRateUserCAD"))) {
            if (winningOption == VoteOption.Increment) {
                redemptionRateUserCAD = redemptionRateUserCAD * 101 / 100; // Increment by 1%
            } else if (winningOption == VoteOption.Decrement) {
                redemptionRateUserCAD = redemptionRateUserCAD * 99 / 100; // Decrement by 1%
            }
        } else if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("redemptionRateStoreCAD"))) {
            if (winningOption == VoteOption.Increment) {
                redemptionRateStoreCAD = redemptionRateStoreCAD * 101 / 100; // Increment by 1%
            } else if (winningOption == VoteOption.Decrement) {
                redemptionRateStoreCAD = redemptionRateStoreCAD * 99 / 100; // Decrement by 1%
            }
        } else if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("minimumReserveRatio"))) {
            if (winningOption == VoteOption.Increment) {
                minimumReserveRatio = minimumReserveRatio + 10000; // Increment by 0.01%
            } else if (winningOption == VoteOption.Decrement) {
                minimumReserveRatio = minimumReserveRatio - 10000; // Decrement by 0.01%
            }
        } else if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("maximumReserveRatio"))) {
            if (winningOption == VoteOption.Increment) {
                maximumReserveRatio = maximumReserveRatio + 10000; // Increment by 0.01%
            } else if (winningOption == VoteOption.Decrement) {
                maximumReserveRatio = maximumReserveRatio - 10000; // Decrement by 0.01%
            }
        } else if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("demurrageRate"))) {
            if (winningOption == VoteOption.Increment) {
                demurrageRate = demurrageRate + 1; // Increment by 1%
            } else if (winningOption == VoteOption.Decrement) {
                demurrageRate = demurrageRate - 1; // Decrement by 1%
            }
        } else if (keccak256(abi.encodePacked(valueName)) == keccak256(abi.encodePacked("reserveRatio"))) {
            if (winningOption == VoteOption.Increment) {
                reserveRatio = reserveRatio + 10000; // Increment by 0.01%
            } else if (winningOption == VoteOption.Decrement) {
                reserveRatio = reserveRatio - 10000; // Decrement by 0.01%
            }
        }
    }

    function resetVotes(string memory valueName) internal {
        votes[valueName].incrementVotes = 0;
        votes[valueName].decrementVotes = 0;
        votes[valueName].leaveVotes = 0;
        votes[valueName].totalVotes = 0;
    }

    function resetVotesForSteward(address steward) internal {
        stewardVotesAll[steward]["redemptionRateUserTTC"] = VoteOption.Leave;
        stewardVotesAll[steward]["redemptionRateStoreTTC"] = VoteOption.Leave;
        stewardVotesAll[steward]["redemptionRateUserCAD"] = VoteOption.Leave;
        stewardVotesAll[steward]["redemptionRateStoreCAD"] = VoteOption.Leave;
        stewardVotesAll[steward]["minimumReserveRatio"] = VoteOption.Leave;
        stewardVotesAll[steward]["maximumReserveRatio"] = VoteOption.Leave;
        stewardVotesAll[steward]["demurrageRate"] = VoteOption.Leave;
        stewardVotesAll[steward]["reserveRatio"] = VoteOption.Leave;
    }

    function getWinningOption(string memory valueName) internal view returns (VoteOption) {
        if (votes[valueName].incrementVotes > votes[valueName].decrementVotes && votes[valueName].incrementVotes > votes[valueName].leaveVotes) {
            return VoteOption.Increment;
        } else if (votes[valueName].decrementVotes > votes[valueName].incrementVotes && votes[valueName].decrementVotes > votes[valueName].leaveVotes) {
            return VoteOption.Decrement;
        } else {
            return VoteOption.Leave;
        }
    }
}
