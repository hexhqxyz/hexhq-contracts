import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import dotenv from "dotenv";
dotenv.config();

const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY as string;

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    ethSepolia: {
      url: `https://rpc.sepolia.org`,
      accounts: [SEPOLIA_PRIVATE_KEY],
      chainId: 11155111,
    },
    polygonAmoyTestnet: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: [SEPOLIA_PRIVATE_KEY],
      chainId: 80002,
    },
    optimismSepolia: {
      url: "https://sepolia.optimism.io",
      chainId: 11155420,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },

    modeTestnet: {
      url: "https://sepolia.mode.network",
      chainId: 919,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
    baseTestnet: {
      url: "https://sepolia.base.org",
      chainId: 84532,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
  },
  sourcify: { enabled: true },
};

export default config;
