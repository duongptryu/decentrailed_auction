#!/usr/bin/ic-repl

load "../env.sh";

"Token payment";
"- Should revert if not owner";
identity account2 "../config/account2.pem";
let resp = call marketplaceCanister.AddSupportedPayment(dip20Canister);
assert resp == variant { Err = variant { Unauthorized } };

identity account1 "../config/account1.pem";
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
