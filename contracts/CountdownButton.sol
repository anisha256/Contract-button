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
        // uint256 joinAt;
        bool choice;
        bool isLeader;
    }

    TestToken public token;

    address public participantAddress;
    address public winnerAddress;
    uint256 public count;

    uint256 public unlockPeriod;
    uint256 public startAt;
    uint256 public endAt;

    uint256 public totalPrize;

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
    constructor(TestToken _token, uint256 _unluckPeriod, uint256 _startAt) {
        token = _token;
        unlockPeriod = _unluckPeriod;
        startAt = _startAt;
        endAt = unlockPeriod.add(startAt);
        state = State.START;
    }

    function onClick(bool _choice)
        public
        inState(State.START)
    {

        participantAddress = msg.sender;
        require(
            block.timestamp < endAt,
            "CANNOT PARTICIPATE"
        );
            count += 1;

        if (_choice) {

            participants[count] = Participant({
                pId:count,
                pAddress: msg.sender,
                balance: token.balanceOf(msg.sender),
                // joinAt: _joinAt,
                choice: _choice,
                isLeader: true
            });

            token.transferFrom(
                msg.sender,
                address(this),
                20000000000000000000
            );
            
        emit Create(count);
        }
            // state = State.COUNTDOWN;

    }
    function getCountdown() 
    public 
    view
    /** inState(State.COUNTDOWN) */
    returns(uint256){
        require(block.timestamp <= endAt,"Countdown is over");
        // state = State.COUNTDOWN_EXPIRED;
        return endAt.sub(block.timestamp);
    }

    function winner() public 
    /**inState(State.COUNTDOWN_EXPIRED)  */ 
    {
        require(
            block.timestamp >= endAt,
            " REWARDS IS LOCKED"
        );
        //declare winner
        Participant memory p = participants[count];
        if(p.isLeader){
        winnerAddress = p.pAddress;
            //withdraw the price
        totalPrize = token.balanceOf(address(this));
        token.transfer(winnerAddress, totalPrize);
        }
     
    }

   
}
