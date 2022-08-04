module {
    // ledger types
    public type Operation = {
        #approve;
        #mint;
        #transfer;
        #transferFrom;
    };

 
    public type TransactionStatus = {
        #succeeded;
        #failed;
    };

    // Dip20 token interface
    public type TxReceipt = {
        #Ok: Nat;
        #Err: {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other;
            #BlockUsed;
            #AmountTooSmall;
        };
    };

    public type Metadata = {
        logo : Text; // base64 encoded logo or logo url
        name : Text; // token name
        symbol : Text; // token symbol
        decimals : Nat8; // token decimal
        totalSupply : Nat; // token total supply
        owner : Principal; // token owner
        fee : Nat; // fee for update calls
    };

    public type IDIP20 = actor {
        transfer : (Principal,Nat) ->  async TxReceipt;
        transferFrom : (Principal,Principal,Nat) -> async TxReceipt;
        allowance : (owner: Principal, spender: Principal) -> async Nat;
        getMetadata: () -> async Metadata;
    };

    //========================================================== Auction

    public type Auction = {
        tokenId: Nat;
        seller: Principal;
        winner: Principal;
        lowestBid: Nat;
        tokenPayment: Principal;
        startTime: Int;
        auctionTime: Int;
        highestBidId: Nat;
        auctionState: AuctionState;
    };

    public type Bid = {
        bidder: Principal;
        amount: Nat;
        bidId: Nat;
    };

    public type AuctionState = {
        #AuctionStarted;
        #AuctionHappenning;
        #AuctionEnded;
        #AuctionCancelled;
    };

}