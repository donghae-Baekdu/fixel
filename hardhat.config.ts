import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";

require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    hardhat: {
      forking: {
        url: `${process.env.NODE_URL}`,
      },
      allowUnlimitedContractSize: true,
    }
  }
};

export default config;