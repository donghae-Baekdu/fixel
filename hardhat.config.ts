import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";

require("dotenv").config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    /*hardhat: {
      forking: {
        url: `${process.env.HARDHAT_NODE_URL}`,
      },
      allowUnlimitedContractSize: true,
    },*/
    hardhat: {
      chainId: 137,
      forking: {
        url: `${process.env.ARBITRUM_NODE_URL}`,
      },
      accounts: [
        {
          privateKey: process.env.ACCOUNT_ZERO_PRIVATE_KEY!,
          balance: "1000000000000000000000",
        },
        {
          privateKey: process.env.ACCOUNT_ONE_PRIVATE_KEY!,
          balance: "1000000000000000000000",
        },
      ],
      allowUnlimitedContractSize: true,
    },
    mumbai: {
      url: `${process.env.POLYGON_MUMBAI_NODE_URL}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
      allowUnlimitedContractSize: true,
    },
    polygon: {
      url: `${process.env.POLYGON_MAINNET_NODE_URL}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
      allowUnlimitedContractSize: true,
    },
  },
};

export default config;
