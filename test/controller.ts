import { ethers } from "hardhat";
import { BigNumber } from "bignumber.js";
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("Position Controller", function () {
    async function deployFixture() {
        const [owner] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("Token");
        const USDC = await Token.deploy();
        await USDC.deployed();
        await USDC.mint(owner.address, ethers.utils.parseUnits("10000000", 18));
        console.log("check");
        const PriceOracle = await ethers.getContractFactory("PriceOracle");
        const PriceOracleContract = await PriceOracle.deploy({});
        await PriceOracleContract.deployed();
        console.log("check");
        await PriceOracleContract.addMarket("NFT1");
        await PriceOracleContract.addMarket("NFT2");
        await PriceOracleContract.addMarket("NFT3");
        await PriceOracleContract.setPriceOracle(0, 1000 * 10 ** 9);
        await PriceOracleContract.setPriceOracle(0, 2000 * 10 ** 9);
        await PriceOracleContract.setPriceOracle(0, 3000 * 10 ** 9);
        console.log("check");
        const Factory = await ethers.getContractFactory("Factory");
        const FactoryContract = await Factory.deploy();
        await FactoryContract.deployed();
        console.log("check");
        await FactoryContract.setPriceOracle(PriceOracleContract.address);
        await FactoryContract.createLpPool(USDC.address);
        console.log("check");
        const lpPoolAddress = await FactoryContract.getLpPool();
        await FactoryContract.createFeePot();
        const feePotAddress = await FactoryContract.getFeePot();
        await FactoryContract.createPositionController();
        const positionControllerAddress =
            await FactoryContract.getPositionController();
        const LpPool = await ethers.getContractFactory("LpPool");
        const LpPoolContract = await LpPool.attach(lpPoolAddress);
        console.log("check!");
        const PositionController = await ethers.getContractFactory(
            "PositionController"
        );
        const PositionControllerContract = await PositionController.attach(
            positionControllerAddress
        );

        await FactoryContract.addMarket("NFT1", 20 * 10 ** 2, 500);
        await FactoryContract.addMarket("NFT2", 20 * 10 ** 2, 500);
        await FactoryContract.addMarket("NFT3", 20 * 10 ** 2, 500);

        const FeePot = await ethers.getContractFactory("FeePot");
        const FeePotContract = await FeePot.attach(feePotAddress);

        return {
            USDC,
            PriceOracleContract,
            FactoryContract,
            LpPoolContract,
            PositionControllerContract,
            FeePotContract,
        };
    }

    it("test", async function () {
        const { LpPoolContract, PositionControllerContract } =
            await loadFixture(deployFixture);
        await PositionControllerContract.openPosition(
            0,
            ethers.utils.parseUnits("10000", 18),
            5 * 100,
            0
        );
        console.log(
            await LpPoolContract.balanceOf(PositionControllerContract.address)
        );
    });
});
