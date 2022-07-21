//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

// import "./TestToken.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EscrowChannel {
    using ECDSA for bytes32;
    /* **************
        ENUMS AND CONSTANTS
    ***************/
    enum ChannelState {
        IS_OPEN,
        CHALLENGE,
        IS_CLOSED
    }

    struct Channel {
        bytes32 channelId;
        address tokenAddress;
        address buyerAddress;
        address sellerAddress;
        uint256 buyerBalance;
        uint256 sellerBalance;
        uint256 nonce;
        uint256 closingTime;
        uint256 challengeTimePeriod;
        ChannelState channelState;
    }
    /* **************
        VARIABLES
    ***************/
    // TestToken public token;

    /* **************
        MAPPINGS
    ***************/
    mapping(bytes32 => Channel) public channels;

    /* **************
        EVENTS
    ***************/
    event ChannelOpened(bytes32 channelId);
    event SellerJoined(bytes32 channelId);
    event ChannelClosed(bytes32 channelId);
    event ChannelOnChallenge(bytes32 channelId);
    event ChannelIsChallenged(bytes32 channelId);

    /* **************
        MODIFIERS
    ***************/

    modifier isOpen(bytes32 id) {
        require(
            channels[id].channelState == ChannelState.IS_OPEN,
            "The channel is not open"
        );
        _;
    }
    modifier channelExists(bytes32 id) {
        require(channels[id].channelId != 0, "Channel doesnot exists");
        _;
    }
    modifier notClosed(bytes32 id) {
        require(
            channels[id].channelState != ChannelState.IS_CLOSED,
            "The channel should not be closed"
        );
        _;
    }
    modifier participantsOnly(bytes32 id) {
        require(
            msg.sender == channels[id].buyerAddress ||
                msg.sender == channels[id].sellerAddress,
            "You are not participant in the channel"
        );
        _;
    }

    // constructor(TestToken _token) {
    //     token = _token;
    // }

    /* **************
        PUBLIC FUNCTIONS
    ***************/

    /**
     * Open a channel.
     *
     *@param sellerAddress Address of the seller
     *@param amount amount of toke to be deposited to the seller
     *@param challengeTimePeriod  challenge period
     */

    function openChannel(
        address tokenAddress,
        address sellerAddress,
        uint256 amount,
        uint256 challengeTimePeriod
    ) public {
        address buyerAddress = msg.sender;
        require(
            buyerAddress != sellerAddress,
            "participants must have different address"
        );
        require(amount != 0, "you must make payments");

        bytes32 channelId = keccak256(
            abi.encodePacked(
                tokenAddress,
                sellerAddress,
                buyerAddress,
                block.number
            )
        );
        Channel memory channel = Channel(
            channelId,
            tokenAddress,
            buyerAddress,
            sellerAddress,
            amount, //buyer balance
            0, //seller balance
            0, //nonce
            0, //closing time
            challengeTimePeriod,
            ChannelState.IS_OPEN
        );
        receiveTokens(channel.tokenAddress, buyerAddress, amount);
        channels[channelId] = channel;
        emit ChannelOpened(channelId);
    }

    function joinChannel(bytes32 channelId, uint256 amount)
        public
        channelExists(channelId)
        isOpen(channelId)
    {
        address sellerAddress = msg.sender;
        Channel storage channel = channels[channelId];
        require(
            channel.sellerAddress == sellerAddress,
            "The channel creator did'nt specify you as seller."
        );

        require(
            channel.sellerBalance == 0,
            "You cannot join to the channel twice."
        );

        require(amount >= 0, "Incorrect amount.");
        receiveTokens(channel.tokenAddress, sellerAddress, amount);
        channel.sellerBalance = amount;
        emit SellerJoined(channelId);
    }

    function closeChannel(
        bytes32 channelId,
        uint256 nonce,
        uint256 buyerBalance,
        uint256 sellerBalance,
        bytes memory buyerSign,
        bytes memory sellerSign
    )
        public
        channelExists(channelId)
        isOpen(channelId)
        participantsOnly(channelId)
    {
        verifySignature(
            channelId,
            nonce,
            buyerBalance,
            sellerBalance,
            buyerSign,
            sellerSign
        );
        updateChannel(channelId, nonce, buyerBalance, sellerBalance);
        Channel memory channel = channels[channelId];
        bool channelNotInChallenge = channel.challengeTimePeriod == 0;
        if (channelNotInChallenge) {
            distributeTokens(channelId);
        } else {
            emit ChannelOnChallenge(channelId);
        }
    }

    modifier isDuringChallengePeriod(bytes32 id) {
        Channel memory channel = channels[id];
        bool timeOver = block.timestamp >
            channel.closingTime + (channel.challengeTimePeriod);
        require(!timeOver, "Time is Over");
        _;
    }
    modifier isOnChallenge(bytes32 id) {
        require(
            channels[id].channelState == ChannelState.CHALLENGE,
            "Channel is not active"
        );
        _;
    }

    function challenge(
        bytes32 channelId,
        uint256 nonce,
        uint256 buyerBalance,
        uint256 sellerBalance,
        bytes memory buyerSign,
        bytes memory sellerSign
    )
        public
        channelExists(channelId)
        participantsOnly(channelId)
        isOnChallenge(channelId)
        isDuringChallengePeriod(channelId)
    {
        Channel memory channel = channels[channelId];
        require(
            nonce > channel.nonce,
            "The nonce must be greater than previous"
        );
        //signature verify
        verifySignature(
            channelId,
            nonce,
            buyerBalance,
            sellerBalance,
            buyerSign,
            sellerSign
        );
        //update channel
        updateChannel(channelId, nonce, buyerBalance, sellerBalance);
        emit ChannelIsChallenged(channelId);
    }

    /* **************
        INTERNAL FUNCTIONS
    ***************/

    function receiveTokens(
        address tokenAddress,
        address from,
        uint256 amount
    ) internal {
        if (amount > 0) {
            ERC20 token = ERC20(tokenAddress);
            token.transferFrom(from, address(this), amount);
        }
    }

    function verifySignature(
        bytes32 channelId,
        uint256 nonce,
        uint256 buyerBalance,
        uint256 sellerBalance,
        bytes memory buyerSign,
        bytes memory sellerSign
    ) internal view {
        Channel memory channel = channels[channelId];
        bytes32 messageHash = keccak256(
            abi.encodePacked(channelId, buyerBalance, sellerBalance, nonce)
        );

        require(
            verifyHash(messageHash, buyerSign, channel.buyerAddress),
            "Buyer signature is invalid"
        );
        require(
            verifyHash(messageHash, sellerSign, channel.sellerAddress),
            "Seller signature is invalid"
        );
    }

    //verifies if the provided hash was signed by the signer
    function verifyHash(
        bytes32 hash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = hash.toEthSignedMessageHash();
        return ethSignedMessageHash.recover(signature) == signer;
    }

    function updateChannel(
        bytes32 channelId,
        uint256 nonce,
        uint256 buyerBalance,
        uint256 sellerBalance
    ) internal {
        //find the channel with channel id
        Channel storage channel = channels[channelId];
        require(
            (buyerBalance + sellerBalance) ==
                (channel.buyerBalance + channel.sellerBalance),
            "total balance doesnot tally"
        );
        channel.nonce = nonce;
        channel.buyerBalance = buyerBalance;
        channel.sellerBalance = sellerBalance;
        if (channel.closingTime == 0) channel.closingTime = block.timestamp;
        channel.channelState = ChannelState.CHALLENGE;
    }

    function distributeTokens(bytes32 channelId) internal notClosed(channelId) {
        Channel storage channel = channels[channelId];
        //channel close
        channel.channelState = ChannelState.IS_CLOSED;
        transferTokens(
            channel.tokenAddress,
            channel.buyerAddress,
            channel.buyerBalance
        );
        transferTokens(
            channel.tokenAddress,
            channel.sellerAddress,
            channel.sellerBalance
        );
        emit ChannelClosed(channelId);
    }

    function transferTokens(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            ERC20 token = ERC20(tokenAddress);
            require(token.transfer(to, amount), "Cannot Transfer");
        }
    }
}
