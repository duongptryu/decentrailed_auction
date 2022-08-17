#!/usr/bin/ic-repl

load "../env.sh";

identity account1 "../config/account1.pem";
"Daction Product NFT";
"- Should revert if token not exist";
let resp = call marketplaceCanister.AddOrder(
    record {
        stepBid=1000;
        startPrice=20000;
        tokenId=opt 1; 
        auctionTime=86400; 
        tokenPayment=dip20Canister; 
        typeAuction=variant {AuctionNFT}; 
        metadataAuction=null
    }
);
assert resp == variant { Err = variant { NotOwnerOfToken } };

"- Account 1 Mint NFT token 1";
identity account1 "../config/account1.pem";
let resp = call dip721Canister.mint(record {url="http://groupbar.me/1"; name="Duong"; description="Day la anh cua Duong"});
assert resp == variant { Ok = 1 : nat };

"- Account 2 Mint NFT token 2";
identity account2 "../config/account2.pem";
let resp = call dip721Canister.mint(record {url="http://groupbar.me/2"; name="Duong2"; description="Day la anh cua Duong2"});
assert resp == variant { Ok = 2 : nat };

"- Account 2 mint NFT token 3";
let resp = call dip721Canister.mint(record {url="http://groupbar.me/3"; name="Duong3"; description="Day la anh cua Duong3"});
assert resp == variant { Ok = 3 : nat };
let resp = call marketplaceCanister.AddOrder(
    record {
        stepBid=1000;
        startPrice=20000;
        tokenId=opt 3; 
        auctionTime=0; 
        tokenPayment=dip20Canister; 
        typeAuction=variant {AuctionNFT}; 
        metadataAuction=null
    }
);
assert resp == variant { Ok = 1 : nat };
" - Should revert if not seller";
identity account3 "../config/account3.pem";
identity account1 "../config/account1.pem";
call dip721Canister.approve(1, account3);
identity account3 "../config/account3.pem";
let resp = call marketplaceCanister.AddOrder(
    record {
        stepBid=1000;
        startPrice=20000;
        tokenId=opt 1; 
        auctionTime=86400; 
        tokenPayment=dip20Canister; 
        typeAuction=variant {AuctionNFT}; 
        metadataAuction=null
    }
);
assert resp == variant { Err = variant { NotSeller } };

"- Should revert if not owner of token 2";
identity account1 "../config/account1.pem";
let resp = call marketplaceCanister.AddOrder(
    record {
        stepBid=1000;
        startPrice=20000;
        tokenId=opt 2; 
        auctionTime=86400; 
        tokenPayment=dip20Canister; 
        typeAuction=variant {AuctionNFT}; 
        metadataAuction=null
    }
);
assert resp == variant { Err = variant { NotOwnerOrApprovedForToken } };

"- Should work correctly when create product with token 1";
identity account1 "../config/account1.pem";
let resp = call marketplaceCanister.AddOrder(
    record {
        stepBid=1000;
        startPrice=20000;
        tokenId=opt 1; 
        auctionTime=86400; 
        tokenPayment=dip20Canister; 
        typeAuction=variant {AuctionNFT}; 
        metadataAuction=null
    }
);
assert resp == variant { Ok = 2 : nat };

"- Should work correctly when create product with token 2 was approved by account 2";
" -- Approve token 2 for account 1";
identity account2 "../config/account2.pem";
call dip721Canister.approve(2, account1);
" -- create nft product with token 2";
identity account1 "../config/account1.pem";
let resp = call marketplaceCanister.AddOrder(
    record {
        stepBid=1000;
        startPrice=20000;
        tokenId=opt 2; 
        auctionTime=86400; 
        tokenPayment=dip20Canister; 
        typeAuction=variant {AuctionNFT}; 
        metadataAuction=null
    }
);
assert resp == variant { Ok = 3 : nat };

"Bid product";
let amountBid1 = 25000;
let amountBid2 = 30000;
let amountLarge = 2000000;
let amountSmall = 500;
" - Should revert if auction not exist";
let resp = call marketplaceCanister.BidAuction(record {auctionId=4; amount=amountBid1});
assert resp == variant { Err = variant { AuctionNotExist } };

" - Should revert if bid amount not approved yet";
let resp = call marketplaceCanister.BidAuction(record {auctionId=2; amount=amountBid1});
assert resp == variant { Err = variant { NotEnoughtBalanceOrNotApprovedYet } };

" - Should revert if bid amount not enought";
let resp = call dip20Canister.approve(marketplaceCanister, amountBid1);
assert resp == variant { Ok = 3 : nat };
let resp = call marketplaceCanister.BidAuction(record {auctionId=2; amount=amountLarge});
assert resp == variant { Err = variant { NotEnoughtBalanceOrNotApprovedYet } };

" - Should revert if bid amount smaller than highest bid amount plus lowest ";
let resp = call marketplaceCanister.BidAuction(record {auctionId=2; amount=amountSmall});
assert resp == variant { Err = variant { BidIsLessThanLowestPrice } };

" - Should work correctly";
let resp = call marketplaceCanister.BidAuction(record {auctionId=2; amount=amountBid1});
assert resp == variant { Ok = 1 : nat };

" - Should revert if already is highest bid";
let resp = call marketplaceCanister.BidAuction(record {auctionId=2; amount=amountBid1});
assert resp == variant { Err = variant { YouAreHighestBidNow } };

" - Should work correctly 2";
identity account2 "../config/account2.pem";
let resp = call dip20Canister.approve(marketplaceCanister, amountBid2);
assert resp == variant { Ok = 5 : nat };
let resp = call marketplaceCanister.BidAuction(record {auctionId=2; amount=amountBid2});
assert resp == variant { Ok = 2 : nat };

