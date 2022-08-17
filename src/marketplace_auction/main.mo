import Array "mo:base/Array";
import Debug "mo:base/Debug";
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

shared(msg) actor class Dacution(dip20: Principal, dip721: Principal, reserve: Principal) {
	public type Time = Time.Time;

	private var storage = reserve;
    private var owner = msg.caller;
	private var dauTokenProvider: Types.IDIP20 = actor(Principal.toText(dip20)) : Types.IDIP20;
	private var nftProvider: Types.IDIP721 = actor(Principal.toText(dip721)) : Types.IDIP721;

    private stable var auctionIdCount: Nat = 0;
	private stable var auctionPendingIdCount: Nat = 0;
    private stable var bitIdCount: Nat = 0;
    private stable var fee = 10;
	private stable var timePending = 86400;

    private stable var supportedPaymentStore: [(Principal, Bool)] = [];
    private stable var auctionStore: [(Nat, Types.Auction)] = [];
    private stable var bidStore: [(Nat, Types.Bid)] = [];
	private stable var listSeller: [(Principal, Types.Seller)] = [];
    private stable var auctionTobidsStore: [(Nat, [(Nat, Types.Bid)])] = [];
	private stable var auctionPendingStore: [(Nat, Types.AuctionPending)] = [];
	private stable var auctionToVotesStore: [(Nat, [(Principal, Types.Vote)])] = [];

    private var idToAuction: HashMap.HashMap<Nat, Types.Auction> = HashMap.fromIter(auctionStore.vals(), 10, Nat.equal, Hash.hash);
    private var idToBid: HashMap.HashMap<Nat, Types.Bid> = HashMap.fromIter(bidStore.vals(), 10, Nat.equal, Hash.hash);
    private var paymentExist: HashMap.HashMap<Principal, Bool> = HashMap.fromIter(supportedPaymentStore.vals(), 10, Principal.equal, Principal.hash);
    private var auctionToBids = HashMap.HashMap<Nat, HashMap.HashMap<Nat, Types.Bid>>(1, Nat.equal, Hash.hash);
	private var idToSeller: HashMap.HashMap<Principal, Types.Seller> = HashMap.fromIter(listSeller.vals(), 10, Principal.equal, Principal.hash);

	private var idToAuctionPending: HashMap.HashMap<Nat, Types.AuctionPending> = HashMap.fromIter(auctionPendingStore.vals(), 10, Nat.equal, Hash.hash);
	private var auctionPendingToVotes = HashMap.HashMap<Nat, HashMap.HashMap<Principal, Types.Vote>>(1, Nat.equal, Hash.hash);


	//SupportedPayment
	public query func GetSupportedPayment() : async [Principal] {
		return Iter.toArray(Iter.map<(Principal, Bool), Principal>(paymentExist.entries(), func ((address: Principal, value: Bool)): Principal{
			return address;
		}));
	};

	public shared({caller}) func AddSupportedPayment(address: Principal) : async Types.SupportedPaymentResult {
		if (caller != owner) {
			return #Err(#Unauthorized);
		};

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
		if (not _isSeller(caller)) {
			return #Err(#NotSeller);
		};
		if(not _isSupportedPayment(data.tokenPayment)) {
			return #Err(#AddressPaymentNotExist);
		};
		assert not Principal.isAnonymous(caller);

		// need transfer nft to market
		if (data.typeAuction == #AuctionNFT) {
			if (Option.isNull(data.tokenId)) {
				return #Err(#InvalidTokenId);
			};

			let ownerToken = await nftProvider.ownerOf(_unwrap(data.tokenId));
			if (Option.isNull(ownerToken)) {
				return #Err(#NotOwnerOfToken);
			};

			if (_unwrap(ownerToken) != caller) {
				try {
					let approvedFor = await nftProvider.getApproved(_unwrap(data.tokenId));
					if (approvedFor != caller) {
						return #Err(#NotOwnerOrApprovedForToken);
					};
				}catch(e) {
					return #Err(#NotOwnerOrApprovedForToken);
				};
			};

			await nftProvider.transferFrom(caller, reserve, _unwrap(data.tokenId));

			auctionIdCount += 1;

			let auctionId = auctionIdCount;
			var auction: Types.Auction = {
				id= auctionId;
				tokenId = data.tokenId;
				seller = caller;
				winner = Principal.fromText("2vxsx-fae");
				stepBid = data.stepBid;
				startPrice = data.startPrice;
				currentPrice = data.startPrice;
				tokenPayment = data.tokenPayment;
				startTime = Time.now();
				auctionTime = data.auctionTime;
				highestBidId = 0;
				auctionState = #AuctionStarted;
				isSend= true;
				isReceived= false;
				metadataAuction = null;
				typeAuction = data.typeAuction;
			};
			idToAuction.put(auctionIdCount, auction);
			auctionToBids.put(auctionIdCount, HashMap.fromIter<Nat, Types.Bid>(Iter.fromArray([]), 1, Nat.equal, Hash.hash));
			return #Ok(auctionId);
		}else if (data.typeAuction == #AuctionRealProduct) {
			auctionPendingIdCount += 1;

			let auctionPendingId = auctionPendingIdCount;
			var auctionPending: Types.AuctionPending = {
				id= auctionPendingIdCount;
				seller = caller;
				stepBid = data.stepBid;
				startPrice = data.startPrice;
				tokenPayment = data.tokenPayment;
				auctionTime = data.auctionTime;
				metadataAuction = data.metadataAuction;
				voteUp = 0;
        		voteDown = 0;
				timePending = timePending;
				timeStart = Time.now();
			};
			idToAuctionPending.put(auctionPendingIdCount, auctionPending);
			auctionPendingToVotes.put(auctionPendingIdCount, HashMap.fromIter<Principal, Types.Vote>(Iter.fromArray([]), 1, Principal.equal, Principal.hash));
			return #Ok(auctionPendingIdCount);
		}else {
			return #Err(#InvalidAuctionType);
		};
	};

	public shared({caller}) func CancelOrder(auctionId: Nat): async Types.CancelOrderResult{
		// assert not Principal.isAnonymous(caller);
		switch(idToAuction.get(auctionId)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				if (auction.seller != caller) {
					return #Err(#NotSeller);
				};
				if (auction.auctionState != #AuctionStarted) {
					return #Err(#CannotCancelOrder);
				};
				if(_unwrap(auctionToBids.get(auctionId)).size() > 0){
					return #Err(#CannotCancelOrder);
				};
				//need transfer nft to owner
				idToAuction.delete(auctionId);
				auctionToBids.delete(auctionId);
				return #Ok(true);
			};
		};
		return #Ok(true)
	};

	public query func GetAuctions() : async [Types.Auction] {
		return Iter.toArray(Iter.map(idToAuction.entries(), func ((id: Nat, auction: Types.Auction)) : Types.Auction {
			auction
		}));
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

	public shared({caller}) func SetAlreadySentProduct(idAuction: Nat): async Types.UpdateAuctionResult {
		switch(idToAuction.get(idAuction)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				if (auction.seller != caller) {
					return #Err(#NotSeller);
				};

				if (auction.typeAuction != #AuctionRealProduct) {
					return #Err(#InvalidAuctionType);
				};

				if (auction.auctionTime + auction.startTime < Time.now()) {
					return #Err(#TimeAuctionNotEnd);
				};
		
				let newAuction: Types.Auction = {
					id = auction.id;
					tokenId = auction.tokenId;
					seller = auction.seller;
					winner = auction.winner;
					stepBid = auction.stepBid;
					startPrice = auction.startPrice;
					currentPrice = auction.startPrice;
					tokenPayment = auction.tokenPayment;
					startTime = auction.startTime;
					auctionTime = auction.auctionTime;
					highestBidId = auction.highestBidId;
					auctionState = auction.auctionState;
					isSend= true;
					isReceived= auction.isReceived;
					metadataAuction = auction.metadataAuction;
					typeAuction = auction.typeAuction;
				};
				
				idToAuction.put(idAuction, newAuction);
				return #Ok(true);
			};
		};
	};

	public shared({caller}) func SetAlreadyReceiveProduct(idAuction: Nat): async  Types.UpdateAuctionResult {
		switch(idToAuction.get(idAuction)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				if (auction.typeAuction != #AuctionRealProduct) {
					return #Err(#InvalidAuctionType);
				};

				if (auction.auctionTime + auction.startTime < Time.now()) {
					return #Err(#TimeAuctionNotEnd);
				};

				switch(_unwrap(auctionToBids.get(idAuction)).get(auction.highestBidId)) {
					case null {
						return #Err(#BidNotExist);
					};
					case (?bid) {
						if (bid.bider != caller) {
							return #Err(#NotWinner);
						};
						
						let newAuction: Types.Auction = {
							id = auction.id;
							tokenId = auction.tokenId;
							seller = auction.seller;
							winner = auction.winner;
							stepBid = auction.stepBid;
							startPrice = auction.startPrice;
							currentPrice = auction.startPrice;
							tokenPayment = auction.tokenPayment;
							startTime = auction.startTime;
							auctionTime = auction.auctionTime;
							highestBidId = auction.highestBidId;
							auctionState = auction.auctionState;
							isSend= auction.isSend;
							isReceived= true;
							metadataAuction = auction.metadataAuction;
							typeAuction = auction.typeAuction;
						};
						
						idToAuction.put(idAuction, newAuction);
						return #Ok(true);
					};
				};
			};
		};
	};

	//=============================================================================================================================================
	//AUCTION BIDs
	public shared({caller}) func BidAuction(data: Types.AuctionBid): async Types.AuctionBidResult {
		// assert not Principal.isAnonymous(caller);
		switch(idToAuction.get(data.auctionId)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				if (auction.auctionTime + auction.startTime >= Time.now()) {
					return #Err(#TimeBidIsExpired);
				};
				if (auction.highestBidId > 0) {
					let highestBid = _unwrap(_unwrap(auctionToBids.get(data.auctionId)).get(auction.highestBidId));
					if (highestBid.bider == caller) {
						return #Err(#YouAreHighestBidNow);
					};
					if (highestBid.amount + auction.stepBid > data.amount) {
						return #Err(#BidIsLessThanHighestBid);
					};
					//transfer token to highest to this owner
				};
				if (data.amount < auction.stepBid + auction.currentPrice) {
					return #Err(#BidIsLessThanLowestPrice);
				};

				//transfer token of this bid to market
				try{
					var resp = await dauTokenProvider.transferFrom(caller, reserve, data.amount);
					switch (resp) {
						case (#Ok(id)) {

						};
						case (_) {
							return #Err(#NotEnoughtBalanceOrNotApprovedYet);
						}
					}
				}catch(e) {
					return #Err(#NotEnoughtBalanceOrNotApprovedYet);
				};

				let bidId = auction.highestBidId + 1;
				let bid: Types.Bid = {
					id = bidId;
					amount = data.amount;
					bider = caller;
					bidId = bidId;
				};

				let newAuction: Types.Auction = {
					id = auction.id;
					tokenId = auction.tokenId;
					seller = auction.seller;
					winner = auction.winner;
					stepBid = auction.stepBid;
					startPrice = auction.startPrice;
					currentPrice =  data.amount;
					tokenPayment = auction.tokenPayment;
					startTime = auction.startTime;
					auctionTime = auction.auctionTime;
					highestBidId = bidId;
					auctionState = auction.auctionState;
					isSend= auction.isSend;
					isReceived= auction.isReceived;
					metadataAuction = auction.metadataAuction;
					typeAuction = auction.typeAuction;
				};
				
				idToAuction.put(data.auctionId, newAuction);
				_unwrap(auctionToBids.get(data.auctionId)).put(bidId, bid);
				return #Ok(bidId)
				}
			};
	};

	public query func GetBids(auctionId: Nat) : async [Types.Bid] {
		switch (auctionToBids.get(auctionId)) {
			case null {
				return []
			};
			case (?bids) {
				return Iter.toArray(Iter.map(bids.entries(), func ((id: Nat, bid: Types.Bid)) : Types.Bid {
					bid
				}));
			};
		};
	};

	public shared({caller}) func ClaimNft(auctionId: Nat): async Types.ClaimAuctionResult {
		// assert not Principal.isAnonymous(caller);
		switch(idToAuction.get(auctionId)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				if (auction.typeAuction != #AuctionNFT) {
					return #Err(#CannotClaimRealProduct);
				};
				if (auction.auctionTime + auction.startTime < Time.now()) {
					return #Err(#TimeAuctionNotEnd);
				};
				if (not Principal.isAnonymous(auction.winner)) {
					return #Err(#NftAlreadyClaimed);
				};
				let highestBidId = auction.highestBidId;

				if (_unwrap(_unwrap(auctionToBids.get(auctionId)).get(highestBidId)).bider != caller) {
					return #Err(#NotOwnerOfBid);
				};
				
				let newAuction: Types.Auction = {
					id = auction.id;
					tokenId = auction.tokenId;
					seller = auction.seller;
					winner = caller;
					stepBid = auction.stepBid;
					startPrice = auction.startPrice;
					currentPrice =  auction.currentPrice;
					tokenPayment = auction.tokenPayment;
					startTime = auction.startTime;
					auctionTime = auction.auctionTime;
					highestBidId = auction.highestBidId;
					auctionState = #AuctionFinished;
					isSend= auction.isSend;
					isReceived= true;
					metadataAuction = auction.metadataAuction;
					typeAuction = auction.typeAuction;
				};
				
				idToAuction.put(auctionId, newAuction);

				//need to be transfer NFT to winner

				return #Ok(true)

			};
		};
	};

	public shared({caller}) func RefundToken(idAuction: Nat, idBid: Nat) : async Types.ClaimAuctionResult {
		// assert not Principal.isAnonymous(caller);
		switch(idToAuction.get(idAuction)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				if (auction.auctionTime + auction.startTime < Time.now()) {
					return #Err(#TimeAuctionNotEnd);
				};

				// Owner of order claim token
				if (auction.highestBidId == idBid) {
					return #Err(#ErrCannotRefundHighestBid)
				};

				if (auction.typeAuction == #AuctionNFT) {
					switch(_unwrap(auctionToBids.get(idAuction)).get(idBid)){
						case null {
							return #Err(#BidAlreadyClaimedOrNotExist); 
						};
						case (?bid) {
							if (bid.bider != caller) {
								return #Err(#NotOwnerOfBid);
							};

							// transfer token to this caller

							//delete this bid
							_unwrap(auctionToBids.get(idAuction)).delete(idBid)
						}
					}
				}else if (auction.typeAuction == #AuctionRealProduct) {

				};

				return #Ok(true)
			};
		};
	};

	public shared({caller}) func ClaimToken(idAuction: Nat) : async Types.ClaimAuctionResult {
		// assert not Principal.isAnonymous(caller);
		switch(idToAuction.get(idAuction)) {
			case null {
				return #Err(#AuctionNotExist);
			};
			case (?auction) {
				if (auction.auctionTime + auction.startTime < Time.now()) {
					return #Err(#TimeAuctionNotEnd);
				};

				// Owner of order claim token
				if (auction.seller != caller) {
					return #Err(#NotSeller)
				};

				if (auction.typeAuction == #AuctionNFT) {
					//transfer token to this caller
					//remove offer
					_unwrap(auctionToBids.get(idAuction)).delete(auction.highestBidId)
				}else if (auction.typeAuction == #AuctionRealProduct) {
					if (not auction.isSend) {
						return #Err(#NotSend)
					};
					if (not auction.isReceived) {
						return #Err(#CustomerNotReceived)
					};
					//transfer token to this caller
					//remove offer
					_unwrap(auctionToBids.get(idAuction)).delete(auction.highestBidId)
				};
				return #Ok(true)
			};
		};
	};

	//=============================================================================================================================================

	//AuctionPending
	public query func GetAuctionPending() : async [Types.AuctionPending] {
		return Iter.toArray(Iter.map(idToAuctionPending.entries(), func ((id: Nat, auction: Types.AuctionPending)) : Types.AuctionPending {
			auction
		}));
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
							id = auctionPendingData.id;
							seller = auctionPendingData.seller;
							stepBid = auctionPendingData.stepBid;
							startPrice = auctionPendingData.startPrice;
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
							id = auctionPendingData.id;
							seller = auctionPendingData.seller;
							stepBid = auctionPendingData.stepBid;
							startPrice = auctionPendingData.startPrice;
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
					id = auctionIdCount;
					tokenId = null;
					seller = auctionPendingData.seller;
					winner = Principal.fromText("2vxsx-fae");
					stepBid = auctionPendingData.stepBid;
					currentPrice = auctionPendingData.startPrice;	
					startPrice = auctionPendingData.startPrice;
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
				auctionToBids.put(auctionIdCount, HashMap.fromIter<Nat, Types.Bid>(Iter.fromArray([]), 1, Nat.equal, Hash.hash));
				idToAuctionPending.delete(idAuctionPending);
				return #Ok(true);
			};
		};
	};

	public shared({caller}) func CancelAuctionPending(id: Nat) : async Types.CancelAuctionPendingResult {
		switch(idToAuctionPending.get(id)) {
			case null {
				return #Err(#AuctionPendingNotExist);
			};
			case (?auction) {
				if (auction.seller != caller) {
					return #Err(#NotSeller);
				};
				if(auction.timeStart + auction.auctionTime > Time.now()) {
					return #Err(#AuctionAlreadyStarted);
				};
				//need transfer nft to owner
				idToAuctionPending.delete(id);
				auctionPendingToVotes.delete(id);
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

	//========================================================== seller ==========================================================================
	public shared({caller}) func BecomeTheSeller(data: Types.SellerCreate): async Types.SellerErrorResult {
		if (Principal.isAnonymous(caller)) {
			return #Err(#Unauthorized);
		};

		if (Option.isSome(idToSeller.get(caller))) {
			return #Err(#AlreadySeller);
		};

		let newSeller: Types.Seller = {
			id = caller;
			username = data.username;
			description = data.description;
			locationTime = data.locationTime;
			social = data.social;
			email = data.email;
		};
		idToSeller.put(caller, newSeller);

		return #Ok(true)
	};

	public shared({caller}) func UpdateSeller(data: Types.SellerUpdate): async Types.SellerErrorResult {
		if (Principal.isAnonymous(caller)) {
			return #Err(#Unauthorized);
		};
		switch (idToSeller.get(caller)) {
			case null {
				return #Err(#NotSeller);
			};
			case (?seller) {
				let newSeller: Types.Seller = {
					id = caller;
					username = data.username;
					description = data.description;
					social = data.social;
					locationTime = data.locationTime;
					email = seller.email;
				};
				return #Ok(true);
			};
		};
	};

	public shared({caller}) func GetSeller(): async [Types.Seller] {
		Iter.toArray(Iter.map(idToSeller.entries(), func ((id: Principal, value: Types.Seller)): Types.Seller {
			return value;
		}));
	};

	public shared query({caller}) func isSeller(): async Bool {
		return _isSeller(caller);
	};

	private func _isSeller(address: Principal) : Bool {
		return Option.isSome(idToSeller.get(address));
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
		listSeller := Iter.toArray(idToSeller.entries());

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
		listSeller := [];

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