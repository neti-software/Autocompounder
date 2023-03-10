import "dotenv/config";
import "solidity-coverage";
import "hardhat-deploy";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import * as fs from "fs";
import * as path from "path";
import { constants } from "ethers";
import { CHAIN_IDS } from "./hardhat/common";
import "hardhat-contract-sizer";

// init typechain for the first time
try {
  fs.readdirSync(path.join(__dirname, "typechain"));
  require("./hardhat/tasks");
} catch { }

const INFURA_KEY = process.env.INFURA_KEY || "";
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || constants.HashZero.slice(2);

module.exports = {
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    hardhat: {
      chainId: CHAIN_IDS.hardhat,
    },
    kovan: {
      chainId: CHAIN_IDS.kovan,
      url: `https://kovan.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    rinkeby: {
      chainId: CHAIN_IDS.rinkeby,
      url: `https://rinkeby.infura.io/v3/${INFURA_KEY}`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    celo: {
      chainId: CHAIN_IDS.celo,
      url: "https://forno.celo.org",
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    },
    alfajores: {
      chainId: CHAIN_IDS.alfajores,
      url: "https://alfajores-forno.celo-testnet.org",
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`], // Using private key instead of mnemonic for vanity deploy
      saveDeployments: true,
    }
  },
  solidity: {
    version: "0.8.9",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/solidity-template/issues/31
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  paths: {
    deploy: "deployments/migrations",
    deployments: "deployments/artifacts",
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
};
