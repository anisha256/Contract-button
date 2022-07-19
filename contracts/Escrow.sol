// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Escrow {
    //VARIABLES
    enum State {
        NOT_INITIATED,
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        COMPLETE
    }

    State public currentState;

    bool public isBuyerIn;
    bool public isSellerIn;

    address public buyer;
    address payable public seller;

    uint256 public price;
    uint256 private paymentAmount;

    //MODIFIERS

    modifier OnlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this function");
        _;
    }

    //FUNCTIONS
    constructor(
        address _buyer,
        address payable _seller,
        uint256 _price
    ) {
        buyer = _buyer;
        seller = _seller;
        //converting wei to ether
        price = _price * (1 ether);
    }

    function initContract() public {
        require(currentState == State.NOT_INITIATED);

        if (msg.sender == buyer) {
            isBuyerIn = true;
        }

        if (msg.sender == seller) {
            isSellerIn = true;
        }
        if (isBuyerIn && isSellerIn) {
            currentState = State.AWAITING_PAYMENT;
        }
    }

    /*
     * buyer to deposit and confirm payment
     */
    function confirmPayment() public payable OnlyBuyer {
        require(currentState == State.AWAITING_PAYMENT, "Already paid");
        //mention price must be equal to msg.value
        require(msg.value == price, "Wrong deposit amount");
        currentState = State.AWAITING_DELIVERY;
    }

    //delivery occurs outside the contract
    //transfer the fund
    function confirmDelivery() public payable OnlyBuyer {
        require(
            currentState == State.AWAITING_DELIVERY,
            "Cannot confirm delivery"
        );
        seller.transfer(price);
        currentState = State.COMPLETE;
    }

    function withdraw() public payable OnlyBuyer {
        require(currentState == State.AWAITING_DELIVERY, "Cannot withdraw");
        payable(msg.sender).transfer(price);
        currentState = State.COMPLETE;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
