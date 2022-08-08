import { ethers } from "hardhat";
import { BigNumber } from "bignumber.js";
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("LP Pool", function () {
    async function deployFixture() {
        const [owner, addr1, addr2, addr3] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("Token");
        const USDC = await Token.deploy();
        await USDC.deployed();
        await USDC.mint(owner.address, ethers.utils.parseUnits("10000000", 18));
        await USDC.mint(addr1.address, ethers.utils.parseUnits("10000000", 18));
        await USDC.mint(addr2.address, ethers.utils.parseUnits("10000000", 18));
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
        await PriceOracleContract.setPriceOracle(0, 2000 * 10 ** 9);
        await PriceOracleContract.setPriceOracle(0, 3000 * 10 ** 9);
        console.log("Set price oracle");

        const Factory = await ethers.getContractFactory("Factory");
        const FactoryContract = await Factory.deploy();
        await FactoryContract.deployed();
        console.log("Factory Contract Deployed");

        await FactoryContract.setPriceOracle(PriceOracleContract.address);
        await FactoryContract.createLpPool(USDC.address);
        const lpPoolAddress = await FactoryContract.getLpPool();
        console.log("LP pool Deployed; address: ", lpPoolAddress);

        await FactoryContract.createFeePot();
        const feePotAddress = await FactoryContract.getFeePot();
        console.log("Fee pot Deployed; address: ", feePotAddress);

        await FactoryContract.createPositionController();
        const positionControllerAddress =
            await FactoryContract.getPositionController();
        console.log("Position Controller Deployed; address: ", positionControllerAddress);

        const LpPool = await ethers.getContractFactory("LpPool");
        const LpPoolContract = await LpPool.attach(lpPoolAddress);

        const FeePot = await ethers.getContractFactory("FeePot");
        const FeePotContract = await FeePot.attach(feePotAddress);

        const PositionController = await ethers.getContractFactory(
            "PositionController"
        );
        const PositionControllerContract = await PositionController.attach(
            positionControllerAddress
        );

        await FactoryContract.addMarket("NFT1", 20 * 10 ** 2, 500);
        await FactoryContract.addMarket("NFT2", 20 * 10 ** 2, 500);
        await FactoryContract.addMarket("NFT3", 20 * 10 ** 2, 500);

        return {
            USDC,
            PriceOracleContract,
            FactoryContract,
            LpPoolContract,
            PositionControllerContract,
            FeePotContract,
            owner, addr1, addr2, addr3
        };
    }

    it("test1", async function () {
        const {
            USDC,
            PriceOracleContract,
            FactoryContract,
            LpPoolContract,
            PositionControllerContract,
            FeePotContract,
            owner, addr1, addr2, addr3
        } =
            await loadFixture(deployFixture);

        console.log(await USDC.balanceOf(addr1.address));
        console.log(await USDC.balanceOf(addr3.address));

        await USDC.transferFrom(addr1.address, addr3.address, 10000);
        console.log(await USDC.balanceOf(addr1.address));
        console.log(await USDC.balanceOf(addr3.address));


    });

    it("test2", async function () {
        const {
            USDC,
            PriceOracleContract,
            FactoryContract,
            LpPoolContract,
            PositionControllerContract,
            FeePotContract,
            owner, addr1, addr2, addr3
        } =
            await loadFixture(deployFixture);

        console.log(await USDC.balanceOf(addr1.address));
        console.log(await USDC.balanceOf(addr3.address));
    });

    it("test3", async function () {
        const { LpPoolContract } =
            await loadFixture(deployFixture);

    });

    it("test4", async function () {
        const { LpPoolContract } =
            await loadFixture(deployFixture);

    });
});
