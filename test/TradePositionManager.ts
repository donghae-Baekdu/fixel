import { BigNumber } from "bignumber.js";
import * as hre from "hardhat";
import { ActionType } from "hardhat/types";
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

async function deployFixture() {
  const [owner, addr1, addr2, addr3] = await hre.ethers.getSigners();

  const Admin = await hre.ethers.getContractFactory("Admin");
  const AdminContract = await Admin.deploy();
  await AdminContract.deployed();
  const adminAddress = AdminContract.address;
  console.log("Admin Contract Deployed");

  const LpPositionManager = await hre.ethers.getContractFactory(
    "LpPositionManager"
  );
  const LpPositionManagerContract = await LpPositionManager.deploy(
    adminAddress
  );
  await LpPositionManagerContract.deployed();
  const lpPositionManagerAddress = LpPositionManagerContract.address;
  await AdminContract.setLpPositionManager(lpPositionManagerAddress);
  console.log(
    "LP Position Manager Deployed; address: ",
    lpPositionManagerAddress
  );

  const TradePositionManager = await hre.ethers.getContractFactory(
    "TradePositionManager"
  );
  const TradePositionManagerContract = await TradePositionManager.deploy(
    AdminContract.address
  );
  await TradePositionManagerContract.deployed();
  const tradePositionManagerAddress = TradePositionManagerContract.address;
  await AdminContract.setTradePositionManager(tradePositionManagerAddress);
  console.log(
    "Trade Position Manager Deployed; address: ",
    tradePositionManagerAddress
  );

  const Vault = await hre.ethers.getContractFactory("Vault");
  const VaultContract = await Vault.deploy(AdminContract.address);
  await VaultContract.deployed();
  const vaultAddress = TradePositionManagerContract.address;
  await AdminContract.setVault(vaultAddress);
  console.log("Vault Deployed; address: ", vaultAddress);

  const PriceOracle = await hre.ethers.getContractFactory("PriceOracle");
  const PriceOracleContract = await PriceOracle.deploy({});
  await PriceOracleContract.deployed();
  const priceOracleAddress = PriceOracleContract.address;
  await AdminContract.setPriceOracle(priceOracleAddress);
  console.log("Price oracle deployed");

  await PriceOracleContract.addFeed("ETH");
  await PriceOracleContract.activateFeed(0);
  await PriceOracleContract.setPriceOracle(0, 1000 * 10 ** 9);
  console.log("Set price oracle");

  // TODO add market

  // TODO add collateral

  // TODO set fee tier

  // TODO set account; impersonate
  // 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b; Arbitrum whale

  // 989.262058860328115093 ETH
  // 260,878,182 USDC
  // 65.13 WBTC

  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b"],
  });

  const whaleSigner = await hre.ethers.getSigner(
    "0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b"
  );

  const usdcContract = await hre.ethers.getContractAt(
    "IERC20",
    "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"
  );

  const wethContract = await hre.ethers.getContractAt(
    "IERC20",
    "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
  );

  const wbtcContract = await hre.ethers.getContractAt(
    "IERC20",
    "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"
  );

  await USDC.connect(owner).approve(
    LpPositionManagerContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr1).approve(
    LpPositionManagerContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr2).approve(
    LpPositionManagerContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr3).approve(
    LpPositionManagerContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );

  return {
    USDC,
    PriceOracleContract,
    AdminContract,
    LpPoolContract: LpPositionManagerContract,
    PositionManagerContract: TradePositionManagerContract,
    owner,
    addr1,
    addr2,
    addr3,
  };
}

describe("Position Controller", async function () {
  let fixture: any;

  it("load fixture", async () => {
    fixture = await deployFixture();
  });
});
