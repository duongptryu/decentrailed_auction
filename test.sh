#!/usr/bin/ic-repl
import marketplaceCanister = "renrk-eyaaa-aaaaa-aaada-cai";
import dip20Canister = "rkp4c-7iaaa-aaaaa-aaaca-cai";
import dip721Canister = "rno2w-sqaaa-aaaaa-aaacq-cai";

identity alice;
"Token payment";
let resp = call marketplaceCanister.AddSupportedPayment(dip20Canister);
resp;