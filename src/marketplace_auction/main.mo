import Array "mo:base/Array";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int = "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import P "mo:base/Prelude";
import Principal "mo:base/Principal";
import Time "mo:base/Time";

import Types "./types"; 

shared(msg) actor class Dacution() {
	public type Time = Time.Time;

    private stable var owner = Principal.fromText("2vxsx-fae");

    private stable var auctionIdCount: Nat = 0;
	private stable var auctionPendingIdCount: Nat = 0;
    private stable var bitIdCount: Nat = 0;
    private stable var fee = 10;
	private stable var timePending = 86400;

    private stable var supportedPaymentStore: [(Principal, Bool)] = [];
    private stable var auctionStore: [(Nat, Types.Auction)] = [];
    private stable var bidStore: [(Nat, Types.Bid)] = [];
    private stable var auctionTobidsStore: [(Nat, [(Nat, Types.Bid)])] = [];
	private stable var auctionPendingStore: [(Nat, Types.AuctionPending)] = [];
	private stable var auctionToVotesStore: [(Nat, [(Principal, Types.Vote)])] = [];

    private var idToAuction: HashMap.HashMap<Nat, Types.Auction> = HashMap.fromIter(auctionStore.vals(), 10, Nat.equal, Hash.hash);
    private var idToBid: HashMap.HashMap<Nat, Types.Bid> = HashMap.fromIter(bidStore.vals(), 10, Nat.equal, Hash.hash);
    private var paymentExist: HashMap.HashMap<Principal, Bool> = HashMap.fromIter(supportedPaymentStore.vals(), 10, Principal.equal, Principal.hash);
    private var auctionToBids = HashMap.HashMap<Nat, HashMap.HashMap<Nat, Types.Bid>>(1, Nat.equal, Hash.hash);

	private var idToAuctionPending: HashMap.HashMap<Nat, Types.AuctionPending> = HashMap.fromIter(auctionPendingStore.vals(), 10, Nat.equal, Hash.hash);
	private var auctionPendingToVotes = HashMap.HashMap<Nat, HashMap.HashMap<Principal, Types.Vote>>(1, Nat.equal, Hash.hash);


	//SupportedPayment
	public query func GetSupportedPayment() : async [Principal] {
		return Iter.toArray(Iter.map<(Principal, Bool), Principal>(paymentExist.entries(), func ((address: Principal, value: Bool)): Principal{
			return address;
		}));
	};

	public shared({caller}) func AddSupportedPayment(address: Principal) : async Types.SupportedPaymentResult {
		// assert caller == owner;
		// assert not Principal.isAnonymous(address);

		if (Option.isSome(paymentExist.get(address))) {
			return #Err(#AddressPaymentAllreadyExist);
		};

		paymentExist.put(address, true);

		#Ok(true)
	};

	public shared query func IsSupportPayment(address: Principal) : async Bool {
		assert not Principal.isAnonymous(address);
		return Option.isSome(paymentExist.get(address));
	};

	public shared({caller}) func RemoveSupportedPayment(address: Principal) : async Types.SupportedPaymentResult {
		assert caller == owner;
		assert not Principal.isAnonymous(address);

		if (Option.isNull(paymentExist.get(address))) {
			return #Err(#AddressPaymentNotExist);
		};

		paymentExist.delete(address);

		#Ok(true)
	};

	private func _isSupportedPayment(address: Principal) : Bool {
		return Option.isSome(paymentExist.get(address));
	};

	
	//ORDER
	public shared({caller}) func AddOrder(data: Types.AuctionCreate): async Types.AddAuctionResult {
		if(not _isSupportedPayment(data.tokenPayment)) {
			return #Err(#AddressPaymentNotExist);
		};
		// assert not Principal.isAnonymous(caller);

		if (data.typeAuction == #AuctionNFT) {
			if (Option.isNull(data.tokenId)) {
				return #Err(#InvalidTokenId);
			};

			auctionIdCount += 1;

			let auctionId = auctionIdCount;
			var auction: Types.Auction = {
				tokenId = data.tokenId;
				seller = caller;
				winner = Principal.fromText("2vxsx-fae");
				lowestBid = data.lowestBid;
				tokenPayment = data.tokenPayment;
				startTime = Time.now();
				auctionTime = data.auctionTime;
				highestBidId = 0;
				auctionState = #AuctionStarted;
				isSend= false;
				isReceived= false;
				metadataAuction = null;
				typeAuction = data.typeAuction;
			};
			idToAuction.put(auctionIdCount, auction);
			return #Ok(true);
		}else if (data.typeAuction == #AuctionRealProduct) {
			auctionPendingIdCount += 1;

			let auctionPendingId = auctionPendingIdCount;
			var auctionPending: Types.AuctionPending = {
				seller = caller;
				lowestBid = data.lowestBid;
				tokenPayment = data.tokenPayment;
				auctionTime = data.auctionTime;
				metadataAuction = data.metadataAuction;
				voteUp = 0;
        		voteDown = 0;
				timePending = timePending;
				timeStart = Time.now();
			};
			idToAuctionPending.put(auctionPendingIdCount, auctionPending);
			var x: HashMap.HashMap<Principal, Types.Vote> = HashMap.fromIter<Principal, Types.Vote>(Iter.fromArray([(Principal.fromText("u5u7i-75ily-wvdre-ob4y6-pahvc-kyrg7-gq44l-zmyd4-7nwwn-mlhxw-zae"), #Up)]), 1, Principal.equal, Principal.hash);
			auctionPendingToVotes.put(auctionPendingIdCount, x);
			return #Ok(true);
		}else {
			return #Err(#InvalidAuctionType);
		};
	};

	public query func GetAuctions() : async [(Nat, Types.Auction)] {
		return Iter.toArray(idToAuction.entries())
	};

	public query func GetAuction(id: Nat) : async Types.GetAuctionResult {
		switch (idToAuction.get(id)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				return #Ok(auction);
			};
		};
	};



	//=============================================================================================================================================

	//AuctionPending
	public query func GetAuctionPending() : async [(Nat, Types.AuctionPending)] {
		return Iter.toArray(idToAuctionPending.entries());
	};

	public query func GetAAuctionPending(id: Nat) : async Types.GetAuctionPendingResult {
		switch (idToAuctionPending.get(id)) {
			case null {
				return #Err(#AuctionPendingNotExist);
			};
			case (?auctionPending) {
				return #Ok(auctionPending);
			};
		};
	};

	public shared({caller}) func VoteAuctionPending(data: Types.VoteMetadata) : async Types.VoteAuctionPendingResult{
		// assert not Principal.isAnonymous(caller);

		//check if caller steak token

		switch(idToAuctionPending.get(data.auctionPendingId)){
			case null{
				return #Err(#AuctionPendingNotExist);
			};
			case (?auctionPendingData){
				if (auctionPendingData.timeStart + auctionPendingData.timePending > Time.now()) {
					return #Err(#TimeVoteIsExpired);
				};
				if (Option.isSome(_unwrap(auctionPendingToVotes.get(data.auctionPendingId)).get(caller))) {
					return #Err(#AlreadyVoted);
				};

				switch(data.vote){
					case (#Up){
						let newAuctionPending = {
							seller = auctionPendingData.seller;
							lowestBid = auctionPendingData.lowestBid;
							tokenPayment = auctionPendingData.tokenPayment;
							auctionTime = auctionPendingData.auctionTime;
							metadataAuction = auctionPendingData.metadataAuction;
							voteUp = auctionPendingData.voteUp + 1;
							voteDown = auctionPendingData.voteDown;
							timePending = auctionPendingData.timePending;
							timeStart = auctionPendingData.timeStart;
						};
						idToAuctionPending.put(data.auctionPendingId, newAuctionPending);
					};
					case(#Down){
						let newAuctionPending = {
							seller = auctionPendingData.seller;
							lowestBid = auctionPendingData.lowestBid;
							tokenPayment = auctionPendingData.tokenPayment;
							auctionTime = auctionPendingData.auctionTime;
							metadataAuction = auctionPendingData.metadataAuction;
							voteUp = auctionPendingData.voteUp;
							voteDown = auctionPendingData.voteDown + 1;
							timePending = auctionPendingData.timePending;
							timeStart = auctionPendingData.timeStart;
						};
						idToAuctionPending.put(data.auctionPendingId, newAuctionPending);
					};
				};

				_unwrap(auctionPendingToVotes.get(data.auctionPendingId)).put(caller, data.vote);
				return #Ok(true);
			};
		};
	};

	public shared query({caller}) func IsVotedAuction(idAuctionPending: Nat): async Bool {
		return _isVotedAuctionPending(idAuctionPending, caller);
	};

	private func _isVotedAuctionPending(idAuctionPending: Nat, address: Principal) : Bool {
		switch(auctionPendingToVotes.get(idAuctionPending)) {
			case null {return false};
			case (?votes) {
				switch(votes.get(address)) {
					case null {return false};
					case (?vote) {return true};
				};
			};
		}
	};

	
	public shared({caller}) func ApproveAuctionPending(idAuctionPending: Nat) : async Types.ApproveAuctionPendingResult {
		assert caller == owner;
		switch (idToAuctionPending.get(idAuctionPending)) {
			case null {
				return #Err(#AuctionPendingNotExist);
			};
			case (?auctionPendingData){
				auctionIdCount += 1;
				let id = auctionIdCount;

				let auction: Types.Auction = {
					tokenId = null;
					seller = auctionPendingData.seller;
					winner = Principal.fromText("2vxsx-fae");
					lowestBid = auctionPendingData.lowestBid;
					tokenPayment = auctionPendingData.tokenPayment;
					startTime = Time.now();
					auctionTime = auctionPendingData.auctionTime;
					highestBidId = 0;
					auctionState = #AuctionStarted;
					metadataAuction = auctionPendingData.metadataAuction;
					isSend= false;
					isReceived= false;
					typeAuction = #AuctionRealProduct;
				};
				idToAuction.put(id, auction);
				idToAuctionPending.delete(idAuctionPending);
				return #Ok(true);
			};
		};
	};

	public query func GetVotedAuctionPending(idAuctionPending: Nat) : async Types.GetVotedAuctionPendingResult {
		switch (idToAuctionPending.get(idAuctionPending)) {
			case null {
				return #Err(#AuctionPendingNotExist);
			};
			case (?auctionPending){
				return #Ok(Iter.toArray(_unwrap(auctionPendingToVotes.get(idAuctionPending)).entries()));
			};
		};
	};

	//=============================================================================================================================================

	//Helper
	private func _unwrap<T>(x : ?T) : T =
        switch x {
            case null { P.unreachable() };
            case (?x_) { x_ };
    };

    system func preupgrade() {
		supportedPaymentStore := Iter.toArray(paymentExist.entries());
		auctionStore := Iter.toArray(idToAuction.entries());
		bidStore := Iter.toArray(idToBid.entries());
		auctionPendingStore := Iter.toArray(idToAuctionPending.entries());

        var auctionBids = Iter.toArray(auctionToBids.entries());
		var size : Nat = auctionBids.size();
		var temp : [var (Nat, [(Nat, Types.Bid)])] = Array.init<(Nat, [(Nat, Types.Bid)])>(size, (0,[]));
		size := 0;
		for ((k, v) in auctionToBids.entries()) {
			temp[size] := (k, Iter.toArray(v.entries()));
			size += 1;
		};
		auctionTobidsStore := Array.freeze(temp);

		var auctionVotes = Iter.toArray(auctionPendingToVotes.entries());
		var sizeVotes : Nat = auctionVotes.size();
		var tempVotes : [var (Nat, [(Principal, Types.Vote)])] = Array.init<(Nat, [(Principal, Types.Vote)])>(sizeVotes, (0,[]));
		sizeVotes := 0;
		for ((k, v) in auctionPendingToVotes.entries()) {
			tempVotes[sizeVotes] := (k, Iter.toArray(v.entries()));
			sizeVotes += 1;
		};
		auctionToVotesStore := Array.freeze(tempVotes);

	};
	
	system func postupgrade() {
		supportedPaymentStore := [];
		auctionStore := [];
		bidStore := [];
		auctionPendingStore := [];

        for ((k, v) in auctionTobidsStore.vals()) {
			let allowed_temp = HashMap.fromIter<Nat, Types.Bid>(v.vals(), 1, Nat.equal, Hash.hash);
			auctionToBids.put(k, allowed_temp);
		};
        auctionTobidsStore := [];

		for ((k, v) in auctionToVotesStore.vals()) {
			let allowed_temp = HashMap.fromIter<Principal, Types.Vote>(v.vals(), 1, Principal.equal, Principal.hash);
			auctionPendingToVotes.put(k, allowed_temp);
		};
		auctionToVotesStore := [];
	};
}