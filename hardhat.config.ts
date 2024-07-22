import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";
dotenv.config();

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY as string;
const GANACHE_PRIVATE_KEY = process.env.GANACHE_PRIVATE_KEY as string;

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  defaultNetwork: "hardhat",
  // etherscan: {
  //   apiKey: ETHERSCAN_API_KEY,
  // },
  networks: {
    // ganache: {
    //   accounts: [GANACHE_PRIVATE_KEY],
    //   url: "http://127.0.0.1:8545",
    //   chainId: 1337,
    // },
    // sepolia: {
    //   // url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   url: `https://rpc.sepolia.org`,
    //   accounts: [SEPOLIA_PRIVATE_KEY],
    //   chainId: 11155111,
    // },
    hardhat: {
      chainId: 1337,
      loggingEnabled: true
    },
  },
  // paths: {
  //   sources: "./contracts",
  //   cache: "./cache",
  //   artifacts: "./artifacts"
  // }
};

export default config;
