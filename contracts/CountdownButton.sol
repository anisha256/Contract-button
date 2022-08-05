// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./TestToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CountdownButton is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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
        uint256 initialDepositAmount;
        bool choice;
        bool isLeader;
    }

    TestToken public token;

    address public participantAddress;
    address public admin;
    uint256 public count;
    uint256 public totalPrize;
    address public winnerAddress;

    //for countdown timer
    uint256 public unlockPeriod;
    uint256 public countdownStart;
    uint256 public countdownEnd;
    bool public reset;
    uint256 public newCountdownEnd;

    //for change in deposit amount
    uint256 public depositAmount;
    uint256 public initialDepositAmount;

    //mapping
    mapping(uint256 => Participant) public participants;
    // mapping(address => Participant) public participants;

    //modifiers
    modifier inState(State _state) {
        require(state == _state);
        _;
    }
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), " MUST BE ADMIN");
        _;
    }

    //events
    event Create(uint256 pcount);

    //functions
    constructor(
        address _admin,
        TestToken _token,
        uint256 _unluckPeriod,
        uint256 _startAt
    ) {
        _setupRole(ADMIN_ROLE, _admin);
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
        if (count == 1) {
            depositAmount = 100000000000000000000;
            initialDepositAmount = 100000000000000000000;
        }
        if (_choice) {
            Participant storage p = participants[count];
            p.pId = count;
            p.pAddress = msg.sender;
            p.balance = token.balanceOf(msg.sender);
            p.joinAt = block.timestamp;
            p.choice = _choice;
            p.isLeader = true;
            p.initialDepositAmount = depositAmount;
            token.transferFrom(
                msg.sender,
                address(this),
                p.initialDepositAmount
            );
            reset = true;
            //-10 min
            countdownEnd = (p.joinAt).add(countdownEnd.sub(p.joinAt).sub(600));
            newCountdownEnd = countdownEnd;
            emit Create(count);
        }
        // state = State.COUNTDOWN;
    }

    function changeDepositAmount(bool _change, uint256 _newAmount)
        public
        onlyAdmin
    {
        require(count >= 1, "ACCEPTS THE INITIALIZED VALUE");
        if (_change) {
            depositAmount = _newAmount;
        } else {
            initialDepositAmount = initialDepositAmount.add(
                10000000000000000000
            );
            depositAmount = initialDepositAmount;
        }
    }

    function getCountdown() public view returns (uint256) {
        require(block.timestamp <= newCountdownEnd, "Countdown is over");
        return newCountdownEnd.sub(block.timestamp);
    }

    function winner() public {
        require(block.timestamp >= newCountdownEnd, " REWARDS IS LOCKED");
        //declare winner
        Participant memory p = participants[count];
        if (p.isLeader) {
            winnerAddress = p.pAddress;
            //withdraw the price
            totalPrize = token.balanceOf(address(this));
            token.transfer(winnerAddress, totalPrize.div(10).mul(9));
            token.transfer(
                0xbB729f824D6C8Ca59106dcE008265A74b785aa99,
                // address(uint160(uint256(ADMIN_ROLE))),
                totalPrize.div(10)
            );
        }
    }
}
