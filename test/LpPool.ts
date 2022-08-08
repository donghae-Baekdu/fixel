import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("LP Pool Test", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployOneYearLockFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, addr1, addr2] = await ethers.getSigners();
    const impersonatedSigner = await ethers.getImpersonatedSigner("0xe982615d461dd5cd06575bbea87624fda4e3de17");
    await impersonatedSigner.sendTransaction({

    });

    const Factory = await ethers.getContractFactory("Factory");
    const factory = await Factory.deploy();

    // factory.createLpPool(owner, );

    return { factory, owner, addr1, addr2 };
  }

  async function deployFixture() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("ERC20");
    const USDC = await Token.deploy("USDC", "USDC");
    await USDC.deployed();
    //await USDC.mint(owner.address, ethers.utils.parseUnits("10000000", 18));
    console.log("check");
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const PriceOracleContract = await PriceOracle.deploy({});
    await PriceOracleContract.deployed();

    const Factory = await ethers.getContractFactory("Factory");
    const FactoryContract = await Factory.deploy();
    await FactoryContract.deployed();
    
    await FactoryContract.createLpPool(owner.address);
    const lpPoolAddress = await FactoryContract.getLpPool();

    await FactoryContract.createFeePot();
    const feePotAddress = await FactoryContract.getFeePot();
    
    await FactoryContract.createPositionController(lpPoolAddress, PriceOracleContract.address);

    const positionControllerAddress =
        await FactoryContract.getPositionController();

    const LpPool = await ethers.getContractFactory("LpPool");
    const LpPoolContract = await LpPool.attach(lpPoolAddress);

    const FeePot = await ethers.getContractFactory("FeePot");
    const FeePotContract = await FeePot.attach(feePotAddress);

    return {
        USDC,
        PriceOracleContract,
        FactoryContract,
        LpPoolContract,
        FeePotContract,
        owner, addr1, addr2, addr3
    };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { factory, owner, addr1, addr2 } = await loadFixture(deployOneYearLockFixture);
    });
  });

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { factory, owner, addr1, addr2 } = await loadFixture(deployOneYearLockFixture);
    });
  });

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { factory, owner, addr1, addr2 } = await loadFixture(deployOneYearLockFixture);
    });
  });
})