import "@nomicfoundation/hardhat-ethers"
import "@nomicfoundation/hardhat-verify"
import "@openzeppelin/hardhat-upgrades"
import * as dotenv from "dotenv"
import "hardhat-gas-reporter"
import { HardhatUserConfig } from "hardhat/config"
import "solidity-coverage"

dotenv.config()

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      viaIR: false,
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  paths: {
    sources: "./contracts",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
    avax_mainnet: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      accounts: [`0x${process.env.MAINNET_PRIVATE_KEY}`],
    },
    avax_testnet: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: [`0x${process.env.TESTNET_PRIVATE_KEY}`],
    },
    arbitrum: {
      url: `${process.env["ARBITRUM_ARCHIVE_NODE_URL"]}`,
      chainId: 42161,
      accounts: [`0x${process.env.MAINNET_PRIVATE_KEY}`],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      avalanche: `${process.env.SNOWTRACE_API_KEY}`,
      bsc: `${process.env.BSC_SCAN_API_KEY}`,
      arbitrumOne: `${process.env.ARBI_SCAN_API_KEY}`,
    },
  },
}

export default config
