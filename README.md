# The Peer2Panel(P2P) Ecosystem
This repository contains the Smart contracts of the P2P ecosystem (NFT, marketplace, collateralized loans and stable coin), and also the detaisl about the SolarT pricing model.

## Smart contracts:
- **SolarT**: Minting, Burning and handling all SolarT NFT informations
- **MarketPlace**: Listing and buying SolarT tokens
- **FungibleSolar**: Collateralized loans and Stable coin backed by SolarTs
All contracts are upgradables and allow for gassless transactions

### Run contracts test
To compile and test the contracts (nodejs and hardhat), you might need the following libraries:
- npm install hardhat
- npm install @nomiclabs/hardhat-ethers
- npm install @openzeppelin/contracts
- npm install @openzeppelin/hardhat-upgrades        
- npm install @openzeppelin/contracts-upgradeable   
- npm install @opengsn/contracts@2.2.6              
//for gassless meta-transactions
- npm install hardhat-contract-sizer                
//If you wanna track the size of your contract (max size is 24KiB on EVM)
- npm install @nomiclabs/hardhat-etherscan          
//to fetch data from etherscan
- npm install dotenv
//To store and read your private keys in your environment variables

Then, you can run the test with
- npx hardhat run scripts/run_test.js

## SolarT value
Our marketplace use a deterministic function to determine the panels value

