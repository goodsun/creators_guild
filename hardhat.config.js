require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200  // Lower runs value for deployment cost optimization
      }
    }
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true // For testing only
    }
  }
};