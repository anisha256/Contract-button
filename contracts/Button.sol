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
    uint256 public unlockPeriod;
    uint256 public totalPrize;

    //mapping
    mapping(address => Participant) public participants;

    //modifiers
    modifier onlyLeader() {
        Participant memory p;
        require(p.isLeader == true, "NOT A LEADER");
        _;
    }
    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    //events
    event Create(uint256 count);

    //functions
    constructor(TestToken _token, uint256 _unluckPeriod) {
        token = _token;
        unlockPeriod = _unluckPeriod;
        state = State.START;
    }

    function onClick(bool _choice, uint256 _joinAt)
        public
        inState(State.START)
    {
        participantAddress = msg.sender;
        require(
            block.timestamp < _joinAt.add(unlockPeriod),
            "CANNOT PARTICIPATE"
        );

        if (_choice) {
            participants[participantAddress] = Participant({
                pAddress: participantAddress,
                balance: token.balanceOf(participantAddress),
                joinAt: _joinAt,
                choice: _choice,
                isLeader: true
            });
            count += 1;
            token.transferFrom(
                participantAddress,
                address(this),
                20000000000000000000
            );
        }
    }

    function winner() public onlyLeader inState(State.COUNTDOWN_EXPIRED) {
        require(block.timestamp >= unlockPeriod, " REWARDS ARENOT UNLOCKED");
        //declare winner

        //withdraw the price
        totalPrize = token.balanceOf(address(this));
        token.transfer(winnerAddress, totalPrize);
    }

    function withdrawPrize() public {}
}