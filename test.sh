#!/usr/bin/ic-repl
load "env.sh";

"Token payment";
"- Should revert if not owner";
identity account2 "./config/account2.pem";
let resp = call marketplaceCanister.AddSupportedPayment(dip20Canister);
assert resp == variant { Err = variant { Unauthorized } };

identity account1 "./config/account1.pem";
"- Should revert if token payment not support";
let resp = call marketplaceCanister.IsSupportPayment(dip20Canister);
assert resp == false;

"- Should revert if already exist principal token address";
call marketplaceCanister.AddSupportedPayment(dip20Canister);
let resp = call marketplaceCanister.AddSupportedPayment(dip20Canister);
assert resp == variant { Err = variant { AddressPaymentAllreadyExist } };

"- Should work exactly";
let resp  = call marketplaceCanister.IsSupportPayment(dip20Canister);
assert resp == true;

"Daction Product NFT";
"- Should revert if token not exist";
let resp = call marketplaceCanister.AddOrder(
    record {
        lowestBid=1000; 
        tokenId=opt 1; 
        auctionTime=86400; 
        tokenPayment=dip20Canister; 
        typeAuction=variant {AuctionNFT}; 
        metadataAuction=null
    }
);
assert resp == variant { Err = variant { NotOwnerOfToken } };

"- Should revert if not owner of token";
identity account2 "./config/account2.pem";
nftProvdier
