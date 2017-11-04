pragma solidity ^0.4.17;

contract Escrow {
    
    address public buyer;
    address public seller;
    address public arbiter;
    
    function Escrow(address _seller, address _arbiter){
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
    }
    
    // buyer or arbiter can execute this method
    function paySeller() {
        if(msg.sender == buyer || msg.sender == arbiter) {
            seller.transfer(this.balance);
        }
    }
    
    // seller or arbiter can execute this method
    function refundBuyer() {
        if(msg.sender == seller || msg.sender == arbiter) {
            buyer.transfer(this.balance);
        }
    }
    
    // enables contract to receive ETH
    // buyer sends ether to the contract address
    function fund() payable returns (bool) {
        return true;
    }
    
    function getBalance() constant returns (uint) {
        return this.balance;
    }
}
