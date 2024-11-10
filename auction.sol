// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.9.0;

contract AuctionCreator{
    Auction[] public auctions;

    function createAuction() public{
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
}

contract Auction {
    address payable public owner;

    uint256 public startBlock;
    uint256 public endBlock;
    string public ipfsHash;
    enum State {
        Started,
        Running,
        Ended,
        Canceled
    }
    State public auctionState;

    uint256 public highestBindingBid;

    address payable public highestBidder;

    mapping(address => uint256) public bids;
    uint256 bidIncrement;

    constructor(address _owner) {
        owner = payable(_owner);
        auctionState = State.Running;
        startBlock = block.number;
        endBlock = startBlock + 4; // a block is created every 15 second. this are the blocks ceated in one week. so auction will run for a week.
        ipfsHash = "";
        bidIncrement = 1000000000000000000;
    }

    modifier notOwner() {
        require(msg.sender != owner);
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier afterStart() {
        require(block.number >= startBlock);
        _;
    }
    modifier beforeEnd() {
        require(block.number <= endBlock);
        _;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a <= b) {
            return a;
        } else {
            return b;
        }
    }

    function placeBid() public payable notOwner afterStart beforeEnd {
        require(auctionState == State.Running);
        require(msg.value >= 100);

        uint256 currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid);
        bids[msg.sender] = currentBid;

        if (currentBid <= bids[highestBidder]) {
            highestBindingBid = min(
                currentBid + bidIncrement,
                bids[highestBidder]
            );
        } else {
            highestBindingBid = min(
                currentBid,
                bids[highestBidder] + bidIncrement
            );
            highestBidder = payable(msg.sender);
        }
    }

    function cancelAuction() public onlyOwner {
        require(auctionState == State.Running);
        auctionState = State.Canceled;
    }

    function finaliseAuction() public {
        require(auctionState == State.Canceled || block.number > endBlock);
        //either the owner or bidder can finalise an auction
        require(msg.sender == owner || bids[msg.sender] > 0, "Not authorized to make withdrawals");

        address payable recipient;
        uint256 value;

        if (auctionState == State.Canceled) {
            //auction was canceled
            recipient = payable(msg.sender);
            value = bids[msg.sender];
        } else {
            // auction completed
            if (msg.sender == owner) {
                // this is the onwer
                recipient = owner;
                value = highestBindingBid;
            } else {
                // bidder
                if (msg.sender == highestBidder) {
                    recipient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                } else {
                    //this is neither the owner nor the highestBidder
                    recipient = payable(msg.sender);
                    value = bids[msg.sender];
                }
            }
        }
        bids[recipient]=0; //to avoid further withdrawals again
        recipient.transfer(value); //withdraw value of fund bidded
    }
}
