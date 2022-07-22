//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract VOTING {
    using SafeMath for uint256;

    //VARIABLES
    enum State {
        STARTED,
        VOTING,
        ENDED
    }
    State public state;

    struct Vote {
        address voterAddress;
        bool choice;
    }
    struct Voter {
        string voterName;
        bool voted;
    }
    // struct Proposal {
    //     string createdBy;
    //     string proposal;
    // }

    uint256 private countResult = 0;
    uint256 public finalResult = 0;
    uint256 public totalVote = 0;
    uint256 public totalVoter = 0;

    address public chairpersonAddress;
    string public chairpersonName;
    string public proposal;

    mapping(uint256 => Vote) private votes;
    mapping(address => Voter) public voters;

    //MODIFIERS

    modifier onlyChairperson() {
        require(
            msg.sender == chairpersonAddress,
            "Not authorized as chairperson"
        );
        _;
    }
    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    //FUNCTIONS

    constructor(string memory _chairpersonName, string memory _proposal) {
        chairpersonAddress = msg.sender;
        chairpersonName = _chairpersonName;
        proposal = _proposal;
        state = State.STARTED;
    }

    function giveRightToVote(address _voterAddress, string memory _voterName)
        public
        inState(State.STARTED)
        onlyChairperson
    {
        Voter memory voter;
        voter.voterName = _voterName;
        voter.voted = false;
        voters[_voterAddress] = voter;
        totalVoter = totalVoter.add(1);
    }

    function startVOTING()
        public
        inState(State.STARTED)
        onlyChairperson
    {
        state == State.VOTING;
    }

    function doVote(bool _choice)
        public
        inState(State.VOTING)
        returns (bool voted)
    {
        bool foundVoter = false;
        if (
            bytes(voters[msg.sender].voterName).length != 0 &&
            !voters[msg.sender].voted
        ) 
        {
            voters[msg.sender].voted = true;
            Vote memory vote;
            vote.voterAddress = msg.sender;
            vote.choice = _choice;
            if (_choice) {
                // countResult = countResult.add(1);
                countResult++;
            }
            votes[totalVote] = vote;
            totalVote++;
            foundVoter = true;
        }
        return foundVoter;
    }

    function closeVote() public onlyChairperson inState(State.VOTING) {
        state = State.ENDED;
        finalResult = countResult;
    }
}
