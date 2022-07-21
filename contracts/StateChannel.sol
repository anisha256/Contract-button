//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./TestToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EscrowChannel {
    enum ChannelState {
        OPEN,
        CHALLENGE,
        CLOSE
    }

    struct Channel {
        //id of channel to prevent 2 channels with same channelId and recipient
        // an index in the channels mapping
        bytes32 channelId;
        address sender;
        address recipient;
        uint256 senderBalance;
        uint256 recipientBalance;
        uint256 nonce;
        uint256 activeTimePeriod;
        uint256 closingTime;
        ChannelState channelState;
    }

    TestToken public token;

    mapping(bytes32 => Channel) public channels;

    event ChannelOpened(bytes32 channelId);

    modifier isOpen(bytes32 id) {
        require(
            channels[id].channelState == ChannelState.OPEN,
            "The channel is not open"
        );
        _;
    }

    constructor(TestToken _token) {
        token = _token;
    }

    /* **************
        PUBLIC FUNCTIONS
    ***************/

    /**
     * Open a channel.
     *
     *@param recipient Address of the recipient
     *@param amount amount of toke to be deposited to the recipient
     *@param activeTimePeriod time period to close the channel
     */

    function openChannel(
        address recipient,
        uint256 amount,
        uint256 activeTimePeriod
    ) public {
        address sender = msg.sender;
        require(
            sender != recipient,
            "participants must have different address"
        );
        require(amount != 0, "you must make payments");

        bytes32 channelId = keccak256(
            abi.encodePacked(recipient, sender, block.number)
        );
        Channel memory channel = Channel(
            channelId,
            sender,
            recipient,
            amount, //sender balance
            0, //recipient balance
            0, //nonce
            0, //closing time
            activeTimePeriod,
            ChannelState.OPEN
        );
        receiveTokens(sender, amount);
        channels[channelId] = channel;
        emit ChannelOpened(channelId);
    }

    function receiveTokens(address from, uint256 amount) internal {
        if (amount > 0) {
            token.transferFrom(from, address(this), amount);
        }
    }
}
