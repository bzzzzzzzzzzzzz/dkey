## About

what is the DKEY protocol?
- a DKEY is a Decryption KEY that an ALICE creates for a paying BOB, that allows access to a specified ENCRYPTED FILE.
- ALICE sells DKEYs by first encrypting a file, then creating a LISTING:
    - a LISTING is where all the necessary data for ALICEs & BOBs to transact is stored and updated 
    - a LISTING exists on the blockchain, and is referenced by the IPFS HASH of the ENCRYPTED FILE
    - in a LISTING, ALICE specifies:
        - how many DKEYs will be for sale
        - a DKEY's sale price
        - what royalty (%) she will receive on all future sales of the DKEY
    - each LISTING tracks:
        - ALICE's blockchain address
        - which BOBs have made bids
        - the value of a given BOB's bid
        - how many DKEYs have been sold
        - which BOBs own DKEYs
- BOB will visit a LISTING (after getting the IPFS HASH from ALICE) and be prompted to make a payment. The SMART CONTRACT will hold the payment. *If* ALICE responds to the payment with a valid DKEY (ie: encrypted for the paying BOB’s public key), *then* the funds will be transferred to ALICE. The SMART CONTRACT uses zkSNARKs to validate the key was properly encrypted. 
- once ALICE has sold her specified amount of DKEYs, BOBs will be able to sell their DKEYs on to CHARLIEs, then CHARLIEs on to DAVEs, etc… all the while, ALICE’s specified royalty amount will be given to her with each sale of a key.
- with each DKEY sale, a small transaction fee (1%) will also be levied against the purchaser — these fees will be accumulated and distributed to $DKEY token holders.

what’s in the development pipeline?
- frontend:
    - main page should be a dashboard, where:
        - dashboard lets you search through LISTINGs
        - when you click on a LISTING from the dashboard, you’ll be taken to BOB’s page where you’ll able to bid, etc
    - better UX
        - make everything more pretty
        - use a framework
        - streamline/simplify the user flow
    - need a more secure method of storing keys than plaintext…
        - a metamask “snap” might work
    - js improvements (error checking, efficiency, etc)
    - needs a sane way to store/retrieve files to/from ipfs 
    - end product should be a static page on ipfs
- protocol:
    - smart contract functionality
        - implement functions that return BOB's funds after some amount of time has elapsed (in the event that ALICE hasn't provided a DKEY)
    - gas optimizations
        - byte packing, change the IPFS HASH from base64 so it can fit into a bytes32, don’t need to save variables to memory in functions, etc
    - auditing
        - smart contracts
        - cryptography (confirm zk circuit & el gamal are implemented correctly)
        - front end (confirm it doesn’t leak keys)
    - needs a subgraph (to read event data)
    - $DKEY ERC20 token + fee distribution mechanism
        - create token contract
            - accumulated fees to be issued to token holders
            - governance(?)
                - token holders can vote on proposals (protocol changes, “official” frontends, etc)
                - a portion of the accumulated fees to go to further protocol development


## Usage

If you don't have them, download Ganache (https://trufflesuite.com/ganache/) and Node (https://nodejs.org/en/download).
- Set up a new Ganache Workspace with
    - NETWORK ID: 5777
    - RPC SERVER: HTTP://127.0.0.1:8080
    - under "TRUFFLE PROJECTS", link to the truffle-config.js file

Use truffle to deploy contracts:
```bash
$ npm install -g truffle
$ truffle migrate
```

Grab the contract address that 'Test' is deployed to.

Serve the website to your browser:
```bash
$ npm install -g http-server
$ cd dist
$ http-server
```

Go to http://localhost:8081/ (or whatever 'http-server' gives) in your browser.

If you don't have it, download the MetaMask extension for your browser.
Set up a new network by going to Settings > Networks > Add a network > Add a network manually (set it up with RPC URL: HTTP://127.0.0.1:8080).
Create two new Metamask Accounts with the top two addresses under the "ACCOUNTS" tab in the Ganache Workspace.
Manually connect MetaMask to the website, if it doesn't do so automatically.

Input one of the two addresses into the top left field - this will be "Alice".
Input the 'Test' smart contract address into the top right field.
Do the same on Bob's page.

The rest should be easy enough to follow...


Big thanks to:
- https://github.com/meixler/web-browser-based-file-encryption-decryption/blob/ec55f1fa9c8c02d8a8048777f67ca77021b9a207/web-browser-based-file-encryption-decryption.html#L255
- https://github.com/Shigoto-dev19/ec-elgamal-circom
- circom/snarkjs
- chatgpt

(for all the packages/pieces of code I've borrowed).

Get in touch if you're interested in collaborating!

-bzz