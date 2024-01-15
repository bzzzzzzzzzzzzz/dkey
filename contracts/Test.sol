// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.7.0 <0.8.20;

interface IVerifier {
  function verifyProof(
    uint256[2] memory _pA,
    uint256[2][2] memory _pB,
    uint256[2] memory _pC,
    uint256[7] memory _pubSignals
  ) external view returns (bool);
}

contract Test {

    IVerifier zkVerifier;

    constructor(address _verifier) {
        zkVerifier = IVerifier(_verifier);
    }

    address payable owner = payable(0x79d78e89419839Ff45EED419B41E5c6b04F839c0); // just a ganache address

    event ListingCreated(bytes ipfsCid, string fileType, uint priceInEth, uint royaltyPercentage);
    event PaymentReceived(bytes indexed ipfsCidIndexed, bytes ipfsCid, uint[2] bobDecryptingPubKey, address bobEthAddress, uint bobBidAmount, bool bobCanFillThisBid);
    event ReencryptedKeyProvided(string fileType, bytes ipfsCid, uint indexed bobDecryptingPubKey, uint[4] dKey);
    event BobsCanNowSellKeys(bytes indexed ipfsCidIndexed);

    mapping (bytes => Listing) public allListings;
    mapping (bytes => bool) public existingListings;

    struct Listing {
        string fileType;
        uint howManyDKeysForSale;
        uint howManyDKeysSold;
        uint priceInEth; 
        uint royaltyPercentage; // should be uint8
        uint poseidonHashedSecretKey; 
        address payable aliceEthAddress;
        mapping (uint => bool) bobsThatHavePaid; // using x-value of bob's decrypting public key only (can't map a uint[2]) -- this should(?) be secure... other option is concatenate, then do the mapping....
        mapping (uint => uint) bobsByBidAmounts;
        mapping (uint => bool) bobsThatHaveBeenProvidedDKeys;
        bool bobsCanSellTheirDkeys;
    } 
    
    function aliceCreatesListing(string memory _fileType, bytes memory _ipfsCid, uint _howManyDKeysForSale, uint _priceInEth, uint _royaltyPercentage, uint _poseidonHashedSecretKey) public {
        require(existingListings[_ipfsCid] == false); 
        require(_royaltyPercentage < 100 && _royaltyPercentage > 0, "royalty amount must be greater than 0% and less than 100%");
        Listing storage newListing = allListings[_ipfsCid];
        newListing.howManyDKeysForSale = _howManyDKeysForSale;
        newListing.howManyDKeysSold = 0;
        newListing.priceInEth = _priceInEth;
        newListing.royaltyPercentage = _royaltyPercentage;
        newListing.fileType = _fileType;
        newListing.poseidonHashedSecretKey = _poseidonHashedSecretKey;
        newListing.aliceEthAddress = payable(msg.sender);
        existingListings[_ipfsCid] = true;
        emit ListingCreated(_ipfsCid, _fileType, _priceInEth, _royaltyPercentage);
    }

    function bobSendsPaymentToListing(bytes memory _ipfsCid, uint[2] memory _bobDecryptingPubKey) public payable {
        Listing storage thisListing = allListings[_ipfsCid];
        require (msg.value > thisListing.priceInEth, "bids must be > alice's specified amount");
        require(allListings[_ipfsCid].bobsThatHavePaid[_bobDecryptingPubKey[0]] == false);
        allListings[_ipfsCid].bobsThatHavePaid[_bobDecryptingPubKey[0]] = true;
        emit PaymentReceived(_ipfsCid, _ipfsCid, _bobDecryptingPubKey, msg.sender, msg.value, allListings[_ipfsCid].bobsCanSellTheirDkeys);
        allListings[_ipfsCid].bobsByBidAmounts[_bobDecryptingPubKey[0]] = msg.value;
    }
    
    function aliceSendsDKey(bytes memory _ipfsCid, uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[7] calldata _pubSignals) public {
        // limits alice to only selling as many dkeys as she originally specified in the Listing
        require(allListings[_ipfsCid].bobsCanSellTheirDkeys == false);

        // save bob's address + dkey to variables (possible that dKey doesn't need to be temporarily saved to memory...)
        uint[2] memory bobDecryptingPubKey;
        bobDecryptingPubKey[0] = _pubSignals[5];
        bobDecryptingPubKey[1] = _pubSignals[6];
        
        uint[4] memory dKey;
        dKey[0] = _pubSignals[0];
        dKey[1] = _pubSignals[1];
        dKey[2] = _pubSignals[2];
        dKey[3] = _pubSignals[3];

        // require poseidon hashed secret key in _pubSignals matches the Listing
        require(_pubSignals[4] == allListings[_ipfsCid].poseidonHashedSecretKey);
        
        // ensure that this bob has not yet been provided a dkey ...... can this be exploited by alice creating a proof for bob's valid x value (_pubSignals[5]) but using a made up y value? (i dont think so -- should only be one valid y coord for a given x coord, and the proof circuit has a check that the point is on curve)
        require(allListings[_ipfsCid].bobsThatHavePaid[bobDecryptingPubKey[0]] == true && allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] == false, "this bob has not paid, or was already provided a dkey");

        // verify proof
        bool result = zkVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        require(result == true);

        // emit event so that Bob can listen for when the dkey is posted on-chain
        emit ReencryptedKeyProvided(allListings[_ipfsCid].fileType, _ipfsCid, bobDecryptingPubKey[0], dKey);
        
        // send 99% of bob's bid amount to alice, and send remainder to "owner" contract. is there going to be a small error (+/- some wei) in what the transfer amounts should be as a result of the division?
        uint256 bidAmount = allListings[_ipfsCid].bobsByBidAmounts[bobDecryptingPubKey[0]];
        uint256 aliceTransferAmount = bidAmount * 99 / 100;
        uint256 ownerTransferAmount = bidAmount * 1 / 100;
        allListings[_ipfsCid].aliceEthAddress.transfer(aliceTransferAmount); 
        owner.transfer(ownerTransferAmount);

        // show that this bob has been provided a dkey (to prevent alice sending the same dkey repeatedly to drain the smart contract & also show that this bob owns a dkey)
        allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] = true;

        // increment how many keys sold by 1
        allListings[_ipfsCid].howManyDKeysSold += 1;

        // check to see if enough dkeys have been sold by alice that bobs can now sell dkeys, and update bool accordingly. also firing an event for bob's front end to know that he is now able to sell his dkey.
        if (allListings[_ipfsCid].howManyDKeysForSale - allListings[_ipfsCid].howManyDKeysSold == 0) {
            allListings[_ipfsCid].bobsCanSellTheirDkeys = true;
            emit BobsCanNowSellKeys(_ipfsCid);
        }
    }
    
    // whole lotta "bob" getting thrown around here... this is 1 bob responding with a dkey to another bob's bid...
    function bobSendsDKey(bytes memory _ipfsCid, uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[7] calldata _pubSignals) public {
        require(allListings[_ipfsCid].bobsCanSellTheirDkeys == true, "alice has not yet sold the req'd # of dkeys in order for bobs to sell");

        uint[2] memory bobDecryptingPubKey;
        bobDecryptingPubKey[0] = _pubSignals[5];
        bobDecryptingPubKey[1] = _pubSignals[6];
        
        uint[4] memory dKey;
        dKey[0] = _pubSignals[0];
        dKey[1] = _pubSignals[1];
        dKey[2] = _pubSignals[2];
        dKey[3] = _pubSignals[3];

        require(_pubSignals[4] == allListings[_ipfsCid].poseidonHashedSecretKey, "poseidon hash of the key does not match");
        
        require(allListings[_ipfsCid].bobsThatHavePaid[bobDecryptingPubKey[0]] == true && allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] == false, "this bob has not paid, or was already provided a dkey");

        bool result = zkVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        require(result == true, "verification of zk proof failed");

        emit ReencryptedKeyProvided(allListings[_ipfsCid].fileType, _ipfsCid, bobDecryptingPubKey[0], dKey);
        
        uint256 bidAmount = allListings[_ipfsCid].bobsByBidAmounts[bobDecryptingPubKey[0]];
        uint256 royaltyAmount = allListings[_ipfsCid].royaltyPercentage;
        uint256 aliceTransferAmount = bidAmount * royaltyAmount / 100;
        uint256 bobTransferAmount = bidAmount * (99 - royaltyAmount) / 100;
        uint256 ownerTransferAmount = bidAmount / 100;
        
        allListings[_ipfsCid].aliceEthAddress.transfer(aliceTransferAmount); 
        payable(msg.sender).transfer(bobTransferAmount); 
        owner.transfer(ownerTransferAmount);

        allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] = true;

        // not needed, but leaving this cuz how many times a key changes hands could still be interesting... maybe for a "listing leaderboard"?
        allListings[_ipfsCid].howManyDKeysSold += 1;
    }

    // TODO: a function to return bob's funds after so many blocks (in the event that alice doesn't respond to payment w a key)
    //  how best to track which bobs paid what amount? add mapping (uint => uint) howMuchEachBobHasPaid to the listing? also needs a reference to that bob's eth address
    //  how is the gas paid for? should be alice that pays for the txn to return bob's funds

    // TODO: create "DKEY" ERC20 token. "owner" contract should distribute the accumulated fees to token holders.

    // TODO: a bidding mechanism. allow bob to bid against other bobs when buying from alice, allow charlie to bid against other charlies when buying from bob, etc
    //  smart contract logic is implemented above, still need:
    //      - alice's & bob's frontends listening for PaymentReceived events, and responding w dkeys to the highest bids first
    //      - create a subgraph for frontends to listen to for event data

}