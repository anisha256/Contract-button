//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

// import "./TestToken.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EscrowChannel {
    using ECDSA for bytes32;
    using SafeMath for uint256;
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
            "The c is not open"
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
            "The c should not be closed"
        );
        _;
    }
    modifier participantsOnly(bytes32 id) {
        require(
            msg.sender == channels[id].buyerAddress ||
                msg.sender == channels[id].sellerAddress,
            "You are not participant in the c"
        );
        _;
    }
    modifier isDuringChallengePeriod(bytes32 id) {
        Channel memory c = channels[id];
        bool timeOver = block.timestamp >
            ((c.closingTime).add(c.challengeTimePeriod));
        require(!timeOver, "Challenge Time is Over");
        _;
    }
    modifier isOnChallenge(bytes32 id) {
        require(
            channels[id].channelState == ChannelState.CHALLENGE,
            "Channel is not challenged"
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
     * Open a c.
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
        Channel memory c = Channel(
            channelId,
            tokenAddress,
            buyerAddress,
            sellerAddress,
            amount,
            0,
            0,
            0,
            challengeTimePeriod,
            ChannelState.IS_OPEN
        );
        transferTokensToContract(c.tokenAddress, buyerAddress, amount);
        channels[channelId] = c;
        emit ChannelOpened(channelId);
    }

    // seller joins the channel
    function joinChannel(bytes32 channelId, uint256 amount)
        public
        channelExists(channelId)
        isOpen(channelId)
    {
        address sellerAddress = msg.sender;
        Channel storage c = channels[channelId];
        require(c.sellerAddress == sellerAddress, "Not a seller.");
        require(c.sellerBalance == 0, "Channel already joined");
        require(amount >= 0, "Incorrect amount.");
        transferTokensToContract(c.tokenAddress, sellerAddress, amount);
        c.sellerBalance = amount;
        emit SellerJoined(channelId);
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
        Channel memory c = channels[channelId];
        require(nonce > c.nonce, "The nonce must be greater than latest");
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
        //must be closed by the one who opened the c
        verifySignature(
            channelId,
            nonce,
            buyerBalance,
            sellerBalance,
            buyerSign,
            sellerSign
        );
        updateChannel(channelId, nonce, buyerBalance, sellerBalance);
        Channel memory c = channels[channelId];
        bool channelNotInChallenge = c.challengeTimePeriod == 0;
        if (channelNotInChallenge) {
            releaseTokens(channelId);
        } else {
            emit ChannelOnChallenge(channelId);
        }
    }

    /* **************
        INTERNAL FUNCTIONS
    ***************/

    function transferTokensToContract(
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
        Channel memory c = channels[channelId];
        bytes32 messageHash = keccak256(
            abi.encodePacked(channelId, buyerBalance, sellerBalance, nonce)
        );

        require(
            verifyHash(messageHash, buyerSign, c.buyerAddress),
            "Buyer signature is invalid"
        );
        require(
            verifyHash(messageHash, sellerSign, c.sellerAddress),
            "Seller signature is invalid"
        );
    }

    //verifies if the provided hash was signed by the signer
    function verifyHash(
        bytes32 messageHash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        return ethSignedMessageHash.recover(signature) == signer;
    }

    function updateChannel(
        bytes32 channelId,
        uint256 nonce,
        uint256 buyerBalance,
        uint256 sellerBalance
    ) internal {
        //find the channel  with channel id
        Channel storage c = channels[channelId];
        require(
            (buyerBalance + sellerBalance) ==
                (c.buyerBalance + c.sellerBalance),
            "total balance doesnot tally"
        );
        c.nonce = nonce;
        c.buyerBalance = buyerBalance;
        c.sellerBalance = sellerBalance;
        if (c.closingTime == 0) c.closingTime = block.timestamp;
        c.channelState = ChannelState.CHALLENGE;
    }

    function releaseTokens(bytes32 channelId) internal notClosed(channelId) {
        Channel storage c = channels[channelId];
        //c close
        c.channelState = ChannelState.IS_CLOSED;
        transferTokens(c.tokenAddress, c.buyerAddress, c.buyerBalance);
        transferTokens(c.tokenAddress, c.sellerAddress, c.sellerBalance);
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
