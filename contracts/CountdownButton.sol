// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./TestToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CountdownButton {
    using SafeMath for uint256;

    //variables

    enum State {
        START,
        COUNTDOWN,
        COUNTDOWN_EXPIRED
    }
    State public state;

    struct Participant {
        uint256 pId;
        address pAddress;
        uint256 balance;
        uint256 joinAt;
        bool choice;
        bool isLeader;
    }

    TestToken public token;

    address public participantAddress;
    address public winnerAddress;
    uint256 public count;
    uint256 public totalPrize;

    uint256 public unlockPeriod;
    uint256 public countdownStart;
    uint256 public countdownEnd;

    bool public reset;
    uint256 public newCountdownEnd;

    //mapping
    mapping(uint256 => Participant) public participants;
    // mapping(address => Participant) public participants;

    //modifiers
    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    //events
    event Create(uint256 pcount);

    //functions
    constructor(
        TestToken _token,
        uint256 _unluckPeriod,
        uint256 _startAt
    ) {
        token = _token;
        unlockPeriod = _unluckPeriod;
        countdownStart = _startAt;
        countdownEnd = unlockPeriod.add(countdownStart);
        state = State.START;
    }

    function onClick(bool _choice) public inState(State.START) {
        participantAddress = msg.sender;
        require(block.timestamp < countdownEnd, "CANNOT PARTICIPATE");
        count += 1;

        if (_choice) {
            // participants[count] = Participant({
            //     pId: count,
            //     pAddress: msg.sender,
            //     balance: token.balanceOf(msg.sender),
            //     joinAt: block.timestamp,
            //     choice: _choice,
            //     isLeader: true
            // });
            Participant storage p = participants[count];
            p.pId = count;
            p.pAddress = msg.sender;
            p.balance = token.balanceOf(msg.sender);
            p.joinAt = block.timestamp;
            p.choice = _choice;
            p.isLeader = true;

            token.transferFrom(msg.sender, address(this), 20000000000000000000);

            reset = true;
            newCountdownEnd = p.joinAt.add(countdownEnd.sub(p.joinAt));
            emit Create(count);
        }
        // state = State.COUNTDOWN;
    }

    function getCountdown() public view returns (uint256) {
        require(block.timestamp <= newCountdownEnd, "Countdown is over");
        return newCountdownEnd.sub(block.timestamp);
    }

    function winner() public /**inState(State.COUNTDOWN_EXPIRED)  */
    {
        require(block.timestamp >= newCountdownEnd, " REWARDS IS LOCKED");
        //declare winner
        Participant memory p = participants[count];
        if (p.isLeader) {
            winnerAddress = p.pAddress;
            //withdraw the price
            totalPrize = token.balanceOf(address(this));
            token.transfer(winnerAddress, totalPrize);
        }
    }
}
