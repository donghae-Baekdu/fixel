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

  const LpPool = await hre.ethers.getContractFactory("LpPool");
  const LpPoolContract = await LpPool.deploy(
    adminAddress
  );
  await LpPoolContract.deployed();
  const lpPoolAddress = LpPoolContract.address;
  await AdminContract.setLpPool(lpPoolAddress);
  console.log("LP pool Deployed; address: ", lpPoolAddress);

  const PositionManager = await hre.ethers.getContractFactory("PositionManager");
  const PositionManagerContract = await PositionManager.deploy(
    AdminContract.address
  );
  await PositionManagerContract.deployed();
  const positionManagerAddress = PositionManagerContract.address;
  await AdminContract.setPositionManager(positionManagerAddress);
  console.log("Position Manager Deployed; address: ", positionManagerAddress);

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

  const whaleSigner = await hre.ethers.getSigner("0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b");

  const usdcContract = await hre.ethers.getContractAt("IERC20", "USDC ADDRESS........");


  await USDC.connect(owner).approve(
    LpPoolContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr1).approve(
    LpPoolContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr2).approve(
    LpPoolContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr3).approve(
    LpPoolContract.address,
    hre.ethers.utils.parseUnits("100000000", 6)
  );

  return {
    USDC,
    PriceOracleContract,
    AdminContract,
    LpPoolContract,
    PositionManagerContract,
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