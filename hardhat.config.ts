import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  networks: {
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.Sepolia_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY!]
    },
    polygonMumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.Mumbai_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY!]
    },
  },

  etherscan: {
    apiKey: {
      sepolia: process.env.EtherScan_API_KEY!,
      polygonMumbai: process.env.PolygonScan_API_KEY!,
    }
  }
};

export default config;
