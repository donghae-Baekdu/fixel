import { ethers } from "hardhat";
import { BigNumber } from "bignumber.js";
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

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
    await PriceOracleContract.setPriceOracle(1, 2000 * 10 ** 9);
    await PriceOracleContract.setPriceOracle(2, 3000 * 10 ** 9);
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
    await USDC.approve(lpPoolAddress, ethers.utils.parseUnits("100000000", 18));
    return {
        USDC,
        PriceOracleContract,
        FactoryContract,
        LpPoolContract,
        PositionControllerContract,
        FeePotContract,
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
            const position = await fixture.PositionControllerContract.positions(
                0
            );
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

            const position = await fixture.PositionControllerContract.positions(
                1
            );

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

            const position = await fixture.PositionControllerContract.positions(
                2
            );
            console.log(position);
            expect(position.margin).equal(ethers.utils.parseUnits("5000", 18));
        });
    });

    describe("close position", async () => {
        it("close position case1", async function () {
            const res = await fixture.PositionControllerContract.closePosition(
                0,
                0
            );
            const position = await fixture.PositionControllerContract.positions(
                0
            );
            console.log(position, res);
        });
    });
});
