require("@nomiclabs/hardhat-waffle");
require("dotenv").config();

const privateKey1 = process.env.PRIVATE_KEY;
const pk1 = process.env.PK_AD1;
const pk2 = process.env.PK_AD2;

module.exports = {
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {
    },
    sepolia: {
      url: "ALCEMY/INFURA URL",
      accounts: [privateKey1, pk1, pk2]
    }
  },
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 100000
  }
}