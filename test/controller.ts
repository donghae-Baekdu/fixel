import { ethers } from "hardhat";
import { BigNumber } from "bignumber.js";
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

async function deployFixture() {
  const [owner, addr1, addr2, addr3] = await ethers.getSigners();

  const Token = await ethers.getContractFactory("USDC");
  const USDC = await Token.deploy();
  await USDC.deployed();

  await USDC.mint(owner.address, ethers.utils.parseUnits("1000000", 6));
  await USDC.mint(addr1.address, ethers.utils.parseUnits("1000000", 6));
  await USDC.mint(addr2.address, ethers.utils.parseUnits("1000000", 6));
  console.log(await USDC.balanceOf(owner.address));
  console.log(await USDC.balanceOf(addr1.address));
  console.log(await USDC.balanceOf(addr2.address));
  console.log("Token minted");

  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const PriceOracleContract = await PriceOracle.deploy({});
  await PriceOracleContract.deployed();
  console.log("Price oracle deployed");
  await PriceOracleContract.addMarket("NFT1");
  await PriceOracleContract.addMarket("NFT2");
  await PriceOracleContract.addMarket("NFT3");
  await PriceOracleContract.setPriceOracle(0, 1000 * 10 ** 9);
  await PriceOracleContract.setPriceOracle(1, 2000 * 10 ** 9);
  await PriceOracleContract.setPriceOracle(2, 3000 * 10 ** 9);
  console.log("Set price oracle");

  const Factory = await ethers.getContractFactory("Factory");
  const FactoryContract = await Factory.deploy();
  await FactoryContract.deployed();
  console.log("Factory Contract Deployed");

  await FactoryContract.setPriceOracle(PriceOracleContract.address);
  const LpPool = await ethers.getContractFactory("LpPool");
  const LpPoolContract = await LpPool.deploy(
    USDC.address,
    FactoryContract.address
  );
  await LpPoolContract.deployed();
  await FactoryContract.setLpPool(LpPoolContract.address);
  const lpPoolAddress = await FactoryContract.getLpPool();
  console.log("LP pool Deployed; address: ", lpPoolAddress);

  //await FactoryContract.createPositionManager();
  const PositionManager = await ethers.getContractFactory("PositionManager");
  const PositionManagerContract = await PositionManager.deploy(
    FactoryContract.address,
    USDC.address,
    lpPoolAddress
  );
  await PositionManagerContract.deployed();

  const positionManagerAddress = PositionManagerContract.address;
  console.log("Position Manager Deployed; address: ", positionManagerAddress);
  await FactoryContract.setPositionManager(positionManagerAddress);
  await LpPoolContract.setFeeTier(0, 0);
  await LpPoolContract.setFeeTier(0, 1);
  //await LpPoolContract.setFeeTier(30, 0);
  //await LpPoolContract.setFeeTier(10, 1);

  await USDC.connect(owner).approve(
    LpPoolContract.address,
    ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr1).approve(
    LpPoolContract.address,
    ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr2).approve(
    LpPoolContract.address,
    ethers.utils.parseUnits("100000000", 6)
  );
  await USDC.connect(addr3).approve(
    LpPoolContract.address,
    ethers.utils.parseUnits("100000000", 6)
  );

  await PositionManagerContract.addMarket("NFT1", 20 * 10 ** 2, 500);
  await PositionManagerContract.addMarket("NFT2", 20 * 10 ** 2, 500);
  await PositionManagerContract.addMarket("NFT3", 20 * 10 ** 2, 500);

  return {
    USDC,
    PriceOracleContract,
    FactoryContract,
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

  describe("openPosition", async () => {
    it("first position", async function () {
      await fixture.PositionControllerContract.openPosition(
        0,
        ethers.utils.parseUnits("10000", 18),
        5 * 100,
        0
      );
      const position = await fixture.PositionControllerContract.positions(0);
      console.log(position);

      expect(
        await fixture.LpPoolContract.balanceOf(
          fixture.PositionControllerContract.address
        )
      ).equal(ethers.utils.parseUnits("10000", 18));
    });

    it("open position after other position get profit", async () => {
      await fixture.PriceOracleContract.setPriceOracle(
        0,
        ethers.utils.parseUnits("1100", 9)
      );

      await fixture.PositionControllerContract.openPosition(
        0,
        ethers.utils.parseUnits("10000", 18),
        5 * 100,
        0
      );

      const position = await fixture.PositionControllerContract.positions(1);

      expect(position.margin).equal(ethers.utils.parseUnits("15000", 18));
      await fixture.PositionControllerContract.closePosition(0, 1);
    });

    it("open position after other position get loss", async () => {
      await fixture.PriceOracleContract.setPriceOracle(
        0,
        ethers.utils.parseUnits("900", 9)
      );

      await fixture.PositionControllerContract.openPosition(
        0,
        ethers.utils.parseUnits("10000", 18),
        5 * 100,
        0
      );

      const position = await fixture.PositionControllerContract.positions(2);
      console.log(position);
      expect(position.margin).equal(ethers.utils.parseUnits("5000", 18));
    });
  });

  describe("close position", async () => {
    it("close position case1", async function () {
      const res = await fixture.PositionControllerContract.closePosition(0, 0);
      const position = await fixture.PositionControllerContract.positions(0);
      console.log(position, res);
    });
  });

  describe("utils", async () => {
    it("get positions by marketId", async function () {
      await fixture.PositionControllerContract.openPosition(
        0,
        ethers.utils.parseUnits("10000", 18),
        5 * 100,
        0
      );
      await fixture.PositionControllerContract.openPosition(
        0,
        ethers.utils.parseUnits("10000", 18),
        5 * 100,
        0
      );
      await fixture.PositionControllerContract.openPosition(
        0,
        ethers.utils.parseUnits("10000", 18),
        5 * 100,
        0
      );
      await fixture.PositionControllerContract.openPosition(
        0,
        ethers.utils.parseUnits("10000", 18),
        5 * 100,
        0
      );
      await fixture.PositionControllerContract.closePosition(0, 3);
      await fixture.PositionControllerContract.closePosition(0, 5);
      await fixture.PositionControllerContract.transferFrom(
        (
          await ethers.getSigners()
        )[0].address,
        "0x6055E8c2ccA5c65181194BA83Ad1A3268849f1E0",
        2
      );
      const index =
        await fixture.PositionControllerContract.getOwnedTokensIndex(
          (
            await ethers.getSigners()
          )[0].address,
          0
        );
      console.log(index);
      const index2 =
        await fixture.PositionControllerContract.getOwnedTokensIndex(
          "0x6055E8c2ccA5c65181194BA83Ad1A3268849f1E0",
          0
        );
      console.log(index2);
    });
  });
});
