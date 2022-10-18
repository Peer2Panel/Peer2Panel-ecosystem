/** @type import('hardhat/config').HardhatUserConfig */

require('dotenv').config();  //usefull to store private key in environment variables
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');


module.exports = {

  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,  //Trying to optimize the bytecode as if a function is called N times
      },
    },
  },

  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  }

};


