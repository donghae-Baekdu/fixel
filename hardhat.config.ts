import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";

require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    hardhat: {
      forking: {
        url: `${process.env.HARDHAT_NODE_URL}`,
      },
      allowUnlimitedContractSize: true,
    },
    mumbai: {
      url: `${process.env.POLYGON_MUMBAI_NODE_URL}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
      allowUnlimitedContractSize: true,
    }
  }
};

export default config;