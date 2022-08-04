import Array "mo:base/Array";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

import Types "./types";

shared(msg) actor class Dacution() {
    private stable var owner = msg.caller;

    private stable var auctionIdCount: Nat = 0;
    private stable var bitIdCount: Nat = 0;
    private stable var fee = 10;

    private stable var supportedPaymentStore: [(Principal, Bool)] = [];
    private stable var auctionStore: [(Nat, Types.Auction)] = [];
    private stable var bidStore: [(Nat, Types.Bid)] = [];
    private stable var auctionTobidsStore: [(Nat, [(Nat, Types.Bid)])] = [];

    private let idToAuction: HashMap.HashMap<Nat, Types.Auction> = HashMap.fromIter(auctionStore.vals(), 10, Nat.equal, Hash.hash);
    private let idToBid: HashMap.HashMap<Nat, Types.Bid> = HashMap.fromIter(bidStore.vals(), 10, Nat.equal, Hash.hash);
    private let paymentExist: HashMap.HashMap<Principal, Bool> = HashMap.fromIter(supportedPaymentStore.vals(), 10, Principal.equal, Principal.hash);
    private var auctionToBids = HashMap.HashMap<Nat, HashMap.HashMap<Nat, Types.Bid>>(1, Nat.equal, Hash.hash);

    system func preupgrade() {
		supportedPaymentStore := Iter.toArray(paymentExist.entries());
		auctionStore := Iter.toArray(idToAuction.entries());
		bidStore := Iter.toArray(idToBid.entries());

        var auctionBids = Iter.toArray(auctionToBids.entries());
		var size : Nat = auctionBids.size();
		var temp : [var (Nat, [(Nat, Types.Bid)])] = Array.init<(Nat, [(Nat, Types.Bid)])>(size, (0,[]));
		size := 0;
		for ((k, v) in auctionToBids.entries()) {
			temp[size] := (k, Iter.toArray(v.entries()));
			size += 1;
		};
		auctionTobidsStore := Array.freeze(temp);
	};
	
	system func postupgrade() {
		supportedPaymentStore := [];
		auctionStore := [];
		bidStore := [];

        for ((k, v) in auctionTobidsStore.vals()) {
			let allowed_temp = HashMap.fromIter<Nat, Types.Bid>(v.vals(), 1, Nat.equal, Hash.hash);
			auctionToBids.put(k, allowed_temp);
		};
        auctionTobidsStore := [];
	};
}