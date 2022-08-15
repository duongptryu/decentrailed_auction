#!/usr/bin/ic-repl
function deploy(wasm) {
  let id = call ic.provisional_create_canister_with_cycles(record { settings = null; amount = null });
  call ic.install_code(
    record {
      arg = encode ();
      wasm_module = wasm;
      mode = variant { install };
      canister_id = id.canister_id;
    },
  );
  id
};

function deployArgs(wasm, addressToken, addressNft) {
  let id = call ic.provisional_create_canister_with_cycles(record { settings = null; amount = null });
  call ic.install_code(
    record {
      arg = encode (addressToken, addressNft);
      wasm_module = wasm;
      mode = variant { install };
      canister_id = id.canister_id;
    },
  );
  id
};

identity alice;
let dip20 = deploy(file ".dfx/local/canisters/dip20/dip20.wasm");
let statusDip20 = call ic.canister_status(dip20);
assert statusDip20.settings.controllers == vec { alice };
let dip20Canister = dip20.canister_id;
"dip20 ===========================================================";
dip20Canister;

let nftSc = deploy(file ".dfx/local/canisters/dip721/dip721.wasm");
let statusDip721 = call ic.canister_status(nftSc);
assert statusDip721.settings.controllers == vec { alice };
let dip721Canister = nftSc.canister_id;
"dip721 ===========================================================";
dip721Canister;

let marketplace = deployArgs(file ".dfx/local/canisters/marketplace_auction/marketplace_auction.wasm", dip20Canister, dip721Canister);
let statusMarketplace = call ic.canister_status(marketplace);
assert statusMarketplace.settings.controllers == vec { alice };
let marketplaceCanister = marketplace.canister_id;
"marketplace ===========================================================";
marketplaceCanister;

"Token payment";
" Should revert if not owner";
identity another;
let resp = call marketplaceCanister.AddSupportedPayment(dip20Canister);
assert resp == variant { Err = variant { Unauthorized } }
