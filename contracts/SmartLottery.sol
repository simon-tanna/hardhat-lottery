// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Enter lottery by paying

// select random winner

// winner selected every x minutes

// Chainlink Oracle to generate randomness

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error Lottery__NotEnoughETHEntered();
error Lottery__TransferFailed();

// SmartLottery to inherit VRFConsumerbase
contract SmartLottery is VRFConsumerBaseV2 {
    // state variables
    uint256 private immutable i_entryFee;
    address payable[] private s_players;
    // Save the VRF Coordinator as a state variable
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    // setting the gasLane as referenced in requestRandomWinner as keyHash
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // CAPS and underscore used for constant variables
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    address private s_recentWinner;

    // Events
    event LotteryEnter(address indexed player);
    event RequestedLotteryWinner(uint256 indexed requestId);
    // event to return previous winners
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2,
        uint256 entryFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entryFee = entryFee;
        // address of VRFCoordinatorV2 is now saved to the vrfCoordinator state variable
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterLottery() public payable {
        // require msg.value == entry fee
        if (msg.value < i_entryFee) {
            revert Lottery__NotEnoughETHEntered();
        }
        s_players.push(payable(msg.sender));
        // Emit an event when we update array or mapping
        // Name events with the function name reversed
        emit LotteryEnter(msg.sender);
    }

    function requestRandomWinner() external {
        // Request Random Number
        // Have number, now do something with it
        // This is a 2 transaction process
        uint256 requestId = i_vrfCoordinator.requestRandomWords( // this will return a uint256 request id as well
            i_gasLane, // this is the gasLane. It is the maximum that you are willing to pay in wei
            i_subscriptionId, // The subscription ID that this contract uses for funding requests.
            REQUEST_CONFIRMATIONS, //How many confirmations the Chainlink node should wait before responding. The longer the node waits, the more secure the random value is. It must be greater than the minimumRequestBlockConfirmations limit on the coordinator contract.
            i_callbackGasLimit, //The limit for how much gas to use for the callback request to your contract's fulfillRandomWords() function.
            NUM_WORDS // How many  random numbers do we want to return
        );
        emit RequestedLotteryWinner(requestId); // Returns requestId from event aka... THE RANDOM NUMBER
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        // pick a winner using a modulo function
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner; // stores the recent winner in state
        // send the money
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    // View / Pure Functions
    function getEntryFee() public view returns (uint256) {
        return i_entryFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
