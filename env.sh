let _ = principal "q4eej-kyaaa-aaaaa-aaaha-cai";
let account1 = principal "u4f2v-igzyj-kgr2d-ipjf5-dnkz6-sl6mm-gxues-usbeb-2bthn-pfjdq-kae";
let dip20 = record { canister_id = principal "qhbym-qaaaa-aaaaa-aaafq-cai" };
let dip20Canister = principal "qhbym-qaaaa-aaaaa-aaafq-cai";
let dip721Canister = principal "qsgjb-riaaa-aaaaa-aaaga-cai";
let ic = principal "aaaaa-aa";
let marketplace = record { canister_id = principal "q4eej-kyaaa-aaaaa-aaaha-cai" };
let marketplaceCanister = principal "q4eej-kyaaa-aaaaa-aaaha-cai";
let nftSc = record { canister_id = principal "qsgjb-riaaa-aaaaa-aaaga-cai" };
let reserveCanister = principal "qvhpv-4qaaa-aaaaa-aaagq-cai";
let reserveSc = record { canister_id = principal "qvhpv-4qaaa-aaaaa-aaagq-cai" };
let statusDip20 = record {
  status = variant { running };
  memory_size = 467_532 : nat;
  cycles = 99_999_348_422_844 : nat;
  settings = record {
    freezing_threshold = 2_592_000 : nat;
    controllers = vec {
      principal "u4f2v-igzyj-kgr2d-ipjf5-dnkz6-sl6mm-gxues-usbeb-2bthn-pfjdq-kae";
    };
    memory_allocation = 0 : nat;
    compute_allocation = 0 : nat;
  };
  module_hash = opt blob "H\d2\b1c\e4\88t\d2\e2\a5\c2\fa\ff\90\12\8d\22|d\27\fb\9b\b7\d72\cc\8f\22D\87\dc\f8";
};
let statusDip721 = record {
  status = variant { running };
  memory_size = 427_027 : nat;
  cycles = 99_999_443_117_540 : nat;
  settings = record {
    freezing_threshold = 2_592_000 : nat;
    controllers = vec {
      principal "u4f2v-igzyj-kgr2d-ipjf5-dnkz6-sl6mm-gxues-usbeb-2bthn-pfjdq-kae";
    };
    memory_allocation = 0 : nat;
    compute_allocation = 0 : nat;
  };
  module_hash = opt blob "(\8f\ae1\87\a7\c1\90\0c\aa\afo\c0\82\04\a5\ab\b5j\80\c4O\adEW\f4\e8\ea\d2+0\83";
};
let statusMarketplace = record {
  status = variant { running };
  memory_size = 541_503 : nat;
  cycles = 99_999_177_801_916 : nat;
  settings = record {
    freezing_threshold = 2_592_000 : nat;
    controllers = vec {
      principal "u4f2v-igzyj-kgr2d-ipjf5-dnkz6-sl6mm-gxues-usbeb-2bthn-pfjdq-kae";
    };
    memory_allocation = 0 : nat;
    compute_allocation = 0 : nat;
  };
  module_hash = opt blob "5\5c^\ad\c6HP\b2\96\fc\c2Y\86:\07\b1\ce\b5|\a5\b6@\cf\d7(\bb)\e6\e1\0fx\a2";
};
let statusReverse = record {
  status = variant { running };
  memory_size = 369_141 : nat;
  cycles = 99_999_584_909_308 : nat;
  settings = record {
    freezing_threshold = 2_592_000 : nat;
    controllers = vec {
      principal "u4f2v-igzyj-kgr2d-ipjf5-dnkz6-sl6mm-gxues-usbeb-2bthn-pfjdq-kae";
    };
    memory_allocation = 0 : nat;
    compute_allocation = 0 : nat;
  };
  module_hash = opt blob "\60\15\8d\00\99,\acy\e5\e3F\fc\de\ad\d6\ffH\ce\03\a77\a4\09\aa\8e\a5\ed\c9N\e8p\9a";
};
