import { ethers } from "hardhat";
import { BigNumber } from "bignumber.js";
import { ActionType } from "hardhat/types";
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
  await PriceOracleContract.setPriceOracle(0, 1000 * 10 ** 6);
  await PriceOracleContract.setPriceOracle(1, 2000 * 10 ** 6);
  await PriceOracleContract.setPriceOracle(2, 3000 * 10 ** 6);
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
  await LpPoolContract.setFeeTier(0, false);
  await LpPoolContract.setFeeTier(0, true);
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

  it("with no pnl", async () => {
    const res = await fixture.PositionManagerContract.openPosition(
      0,
      5 * 100,
      ethers.utils.parseUnits("10000", 6),
      0
    );

    const position = await fixture.PositionManagerContract.positions(0);
    const test2 =
      await fixture.PositionManagerContract.calculateMarginWithFundingFee(0);
    console.log(
      convertToNumber(position.margin, 18),
      convertToNumber(test2, 18),
      convertToNumber(position.notionalValue, 18)
    );
    const inputAmount = await fixture.LpPoolContract.getInputAmountToMint(
      ethers.utils.parseUnits("10000", 18)
    );
    console.log("1", convertToNumber(inputAmount, 6));
    console.log(
      convertToNumber(await fixture.USDC.balanceOf(fixture.owner.address), 6)
    );
    await fixture.PositionManagerContract.removeMargin(
      0,
      ethers.utils.parseUnits(
        convertToBigNumber(position.margin).dividedBy(5).toFixed(0),
        0
      ),
      ethers.utils.parseUnits(
        convertToBigNumber(position.notionalValue).dividedBy(2).toFixed(0),
        0
      )
    );
    const positionAfter = await fixture.PositionManagerContract.positions(0);
    const test =
      await fixture.PositionManagerContract.calculateMarginWithFundingFee(0);
    const inputAmount2 = await fixture.LpPoolContract.getInputAmountToMint(
      ethers.utils.parseUnits("8000", 18)
    );
    console.log(
      convertToNumber(positionAfter.margin, 18),
      convertToNumber(test, 18),
      convertToNumber(positionAfter.notionalValue, 18)
    );
    console.log("2", convertToNumber(inputAmount2, 6));
    console.log(
      convertToNumber(await fixture.USDC.balanceOf(fixture.owner.address), 6)
    );
  });
  /*
  describe("openPosition", async () => {
    it("first position", async function () {
      await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      const position = await fixture.PositionManagerContract.positions(0);
      console.log(position);

      expect(
        await fixture.LpPoolContract.balanceOf(
          fixture.PositionManagerContract.address
        )
      ).equal(ethers.utils.parseUnits("10000", 18));
    });

    it("open position after other position get profit", async () => {
      await fixture.PriceOracleContract.setPriceOracle(
        0,
        ethers.utils.parseUnits("1100", 6)
      );

      await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      const pos = await fixture.PositionManagerContract.positions(0);
      console.log("pos1", pos);
      const position = await fixture.PositionManagerContract.positions(1);
      console.log("pos2", position);
      expect(position.margin).equal(ethers.utils.parseUnits("15000", 18));
      await fixture.PositionManagerContract.closePosition(0, 1);
    });

    it("open position after other position get loss", async () => {
      await fixture.PriceOracleContract.setPriceOracle(
        0,
        ethers.utils.parseUnits("900", 6)
      );

      await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );

      const position = await fixture.PositionManagerContract.positions(2);
      console.log(position);
      expect(position.margin).equal(ethers.utils.parseUnits("5000", 18));
    });
  });

  describe("close position", async () => {
    it("close position case1", async function () {
      const res = await fixture.PositionManagerContract.closePosition(0, 0);
      const position = await fixture.PositionManagerContract.positions(0);
      console.log(position, res);
    });
  });

  describe("utils", async () => {
    it("get positions by marketId", async function () {
      await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      await fixture.PositionManagerContract.closePosition(0, 3);
      await fixture.PositionManagerContract.closePosition(0, 5);
      await fixture.PositionManagerContract.transferFrom(
        (
          await ethers.getSigners()
        )[0].address,
        "0x6055E8c2ccA5c65181194BA83Ad1A3268849f1E0",
        2
      );
      const index = await fixture.PositionManagerContract.getOwnedTokensIndex(
        (
          await ethers.getSigners()
        )[0].address,
        0
      );
      console.log(index);
      const index2 = await fixture.PositionManagerContract.getOwnedTokensIndex(
        "0x6055E8c2ccA5c65181194BA83Ad1A3268849f1E0",
        0
      );
      console.log(index2);
    });
  });

  describe("Funding Fee", async () => {
    it("calculate positive funding fee with long position", async () => {
      await fixture.PositionManagerContract.applyFundingRate(0, 0, 1000);
      const res = await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      const position = await fixture.PositionManagerContract.positions(7);

      await fixture.PositionManagerContract.applyFundingRate(0, 1, 200);
      const res2 =
        await fixture.PositionManagerContract.calculatePositionFundingFee(7);
      expect(res2.sign).equal(0);

      expect(res2.fundingFee).equal(
        ethers.utils.parseUnits(
          new BigNumber(position.notionalValue.toString())
            .dividedBy(50)
            .toFixed(),
          0
        )
      );
    });

    it("calculate negative funding fee with short position", async () => {
      const res = await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        1
      );
      const position = await fixture.PositionManagerContract.positions(8);

      await fixture.PositionManagerContract.applyFundingRate(0, 1, 200);
      const res2 =
        await fixture.PositionManagerContract.calculatePositionFundingFee(8);

      expect(res2.sign).equal(1);

      expect(res2.fundingFee).equal(
        ethers.utils.parseUnits(
          new BigNumber(position.notionalValue.toString())
            .dividedBy(50)
            .toFixed(),
          0
        )
      );
    });

    it("apply positive funding fee", async () => {
      const res = await fixture.PositionManagerContract.openPosition(
        0,
        5 * 100,
        ethers.utils.parseUnits("10000", 6),
        0
      );
      const position = await fixture.PositionManagerContract.positions(9);
      const check1 = await fixture.LpPoolContract.getAmountToMint(
        ethers.utils.parseUnits("10000", 6),
        ethers.utils.parseUnits("10000", 6)
      );
      const test =
        await fixture.PositionManagerContract.calculatePositionFundingFee(9);
      await fixture.PositionManagerContract.applyFundingRate(0, 1, 200);
      await fixture.PositionManagerContract.applyFundingFeeToPosition(9);
      const check2 = await fixture.LpPoolContract.getAmountToMint(
        ethers.utils.parseUnits("10000", 6),
        ethers.utils.parseUnits("10000", 6)
      );
      console.log(
        "check",
        convertToString(check1._amountToMint),
        convertToString(check2._amountToMint)
      );
      const positionAfter = await fixture.PositionManagerContract.positions(9);
      const res2 =
        await fixture.PositionManagerContract.calculatePositionFundingFee(9);
      expect(res2.fundingFee).equal(
        ethers.utils.parseUnits(new BigNumber(0).toFixed(), 0)
      );

      expect(positionAfter.margin).equal(
        new BigNumber(position.notionalValue.toString())
          .multipliedBy(0.02)
          .plus(new BigNumber(position.margin.toString()))
          .toFixed()
      );
    });
  });

  describe("Partial Fill", async () => {
    describe("addMargin", async () => {
      it("with no pnl", async () => {
        const res = await fixture.PositionManagerContract.openPosition(
          0,
          5 * 100,
          ethers.utils.parseUnits("10000", 6),
          0
        );

        const position = await fixture.PositionManagerContract.positions(10);

        console.log(
          convertToString(position.margin),
          convertToString(position.notionalValue)
        );
        await fixture.PositionManagerContract.addMargin(
          10,
          ethers.utils.parseUnits("10000", 6),
          ethers.utils.parseUnits("50000", 6)
        );
        const positionAfter = await fixture.PositionManagerContract.positions(
          10
        );
        console.log(
          convertToNumber(positionAfter.margin, 18),
          convertToNumber(positionAfter.notionalValue, 18)
        );
      });

      it("check pnl after add margin", async () => {
        const test1 = await fixture.PositionManagerContract.calculateMargin(10);
        await fixture.PriceOracleContract.setPriceOracle(0, 990 * 10 ** 6);
        const test2 = await fixture.PositionManagerContract.calculateMargin(10);
        const test3 = await fixture.PositionManagerContract.positions(10);
        console.log(
          convertToNumber(test1, 18),
          convertToNumber(test2, 18),
          convertToNumber(test3.margin, 18),
          convertToNumber(test3.price, 6)
        );
      });
      it("add margin after get pnl", async () => {
        const test1 = await fixture.PositionManagerContract.calculateMargin(10);
        const test3 = await fixture.PositionManagerContract.positions(10);
        const inputAmount = await fixture.LpPoolContract.getInputAmountToMint(
          ethers.utils.parseUnits("15000", 18)
        );
        console.log("input amount", convertToNumber(inputAmount, 6));

        await fixture.PositionManagerContract.addMargin(
          10,
          ethers.utils.parseUnits(convertToString(inputAmount), 0),
          ethers.utils.parseUnits(convertToString(inputAmount), 0).mul(3)
        );
        const test5 = await fixture.PositionManagerContract.positions(10);
        const test6 = await fixture.PositionManagerContract.calculateMargin(10);
        console.log(
          "before get profit",
          convertToNumber(test6, 18),
          convertToNumber(test5.notionalValue, 18)
        );
        await fixture.PriceOracleContract.setPriceOracle(0, 1089 * 10 ** 6);
        const test2 = await fixture.PositionManagerContract.calculateMargin(10);
        const test4 = await fixture.PositionManagerContract.positions(10);

        console.log(
          "margin",
          convertToNumber(test1, 18),
          convertToNumber(test2, 18)
        );

        console.log(
          "initial margin",
          convertToNumber(test3.margin, 18),
          convertToNumber(test4.margin, 18)
        );
      });
    });

    describe("removeMargin", async () => {
      it("with no pnl", async () => {
        const res = await fixture.PositionManagerContract.openPosition(
          0,
          5 * 100,
          ethers.utils.parseUnits("10000", 6),
          0
        );

        const position = await fixture.PositionManagerContract.positions(11);
        const test2 = await fixture.PositionManagerContract.calculateMargin(11);
        console.log(
          convertToNumber(position.margin, 18),
          convertToNumber(test2, 18),
          convertToNumber(position.notionalValue, 18)
        );
        await fixture.PositionManagerContract.removeMargin(
          11,
          ethers.utils.parseUnits(
            convertToBigNumber(position.margin).dividedBy(5).toFixed(0),
            0
          ),
          ethers.utils.parseUnits(
            convertToBigNumber(position.notionalValue).dividedBy(2).toFixed(0),
            0
          )
        );
        const positionAfter = await fixture.PositionManagerContract.positions(
          11
        );
        const test = await fixture.PositionManagerContract.calculateMargin(11);
        console.log(
          convertToNumber(positionAfter.margin, 18),
          convertToNumber(test, 18),
          convertToNumber(positionAfter.notionalValue, 18)
        );
      });
    });
  });*/
});

function convertToString(input: any) {
  return new BigNumber(input.toString()).toFixed();
}

function convertToBigNumber(input: any) {
  return new BigNumber(input.toString());
}

function convertToNumber(input: any, decimal: number) {
  return new BigNumber(input.toString())
    .dividedBy(new BigNumber(10).exponentiatedBy(decimal))
    .toFixed(0);
}
