//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Game {
    address public player1;
    address public player2;

    uint256 public amount;
    uint256 public timeoutInterval;
    bool public gameOver;

    mapping(address => address) public signerFor;

    struct GameState {
        uint8 seq;
        uint8 num;
        address whoseTurn;
    }

    event GameStarted();
    event TimeoutStarted();
    event MoveMade(address player, uint8 seq, uint8 value);

    function open(uint256 _timeoutInterval, address signer) public payable {
        player1 = msg.sender;
        signerFor[player1] = signer;
        amount = msg.value;
        timeoutInterval = _timeoutInterval;
    }

    function join(address signer) public payable {
        require(player2 == address(0x0), "Game has already started");
        require(!gameOver, "game was canceled");
        require(msg.value == amount, "wrong amount");
        player1 = msg.sender;
        signerFor[player2] = signer;
        emit GameStarted();
    }
}
