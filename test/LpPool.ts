import { ethers } from "hardhat";
import { BigNumber } from "bignumber.js";
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("LP Pool", function () {
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
        await LpPoolContract.setFeeTier(10, false);
        await LpPoolContract.setFeeTier(0, true);
      
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

    function convertUnit(value: string, decimals: number) {
        return ethers.utils.parseUnits(value, decimals);
    }

    let statusCache: any;

    describe("Add LP Liquidity", async function () {
        it("Initial Add LP Liquidity", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionManagerContract,
                owner,
                addr1,
                addr2,
                addr3,
            } = await loadFixture(deployFixture);

            await LpPoolContract.connect(addr1).addLiquidity(
                addr1.address,
                convertUnit("100", 6),
                convertUnit("500", 6),
                1
            );

            const afterBalance = await USDC.balanceOf(addr1.address);
            const addr1LpPosition = await LpPoolContract.getLpPosition(addr1.address);
            const margin = addr1LpPosition[0]
            const notionalEntryAmount = addr1LpPosition[1]
            const lpPositionSize = addr1LpPosition[2]

            expect(afterBalance).to.equal(
                convertUnit("999900", 6)
            );
            expect(margin).to.equal(
                convertUnit("99.5", 6)
            );
            expect(notionalEntryAmount).to.equal(
                convertUnit("500", 6)
            );
            expect(lpPositionSize).to.equal(
                convertUnit("500", 18)
            );

            statusCache = {
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
        });

        it("Additional Add LP Liquidity", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionManagerContract,
                owner,
                addr1,
                addr2,
                addr3,
            } = statusCache;

            await LpPoolContract.connect(addr2).addLiquidity(
                addr2.address,
                convertUnit("100", 6),
                convertUnit("500", 6),
                1
            );

            const afterBalance = await USDC.balanceOf(addr2.address);
            const addr1LpPosition = await LpPoolContract.getLpPosition(addr2.address);
            const margin = addr1LpPosition[0]
            const notionalEntryAmount = addr1LpPosition[1]
            const lpPositionSize = addr1LpPosition[2]

            expect(afterBalance).to.equal(
                convertUnit("999900", 6)
            );
            expect(margin).to.equal(
                convertUnit("99.5", 6)
            );
            expect(notionalEntryAmount).to.equal(
                convertUnit("500", 6)
            );
            expect(lpPositionSize).to.equal(
                convertUnit("500", 18)
            );

            statusCache = {
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
        });

        it("Only add margin", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionManagerContract,
                owner,
                addr1,
                addr2,
                addr3,
            } = statusCache;

            await LpPoolContract.connect(addr1).addLiquidity(
                addr1.address,
                convertUnit("100", 6),
                "0",
                1
            );

            const afterBalance = await USDC.balanceOf(addr1.address);
            const addr1LpPosition = await LpPoolContract.getLpPosition(addr1.address);
            const margin = addr1LpPosition[0]
            const notionalEntryAmount = addr1LpPosition[1]
            const lpPositionSize = addr1LpPosition[2]

            expect(afterBalance).to.equal(
                convertUnit("999800", 6)
            );
            expect(margin).to.equal(
                convertUnit("199.5", 6)
            );
            expect(notionalEntryAmount).to.equal(
                convertUnit("500", 6)
            );
            expect(lpPositionSize).to.equal(
                convertUnit("500", 18)
            );

            statusCache = {
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
        });

        it("Only add position", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionManagerContract,
                owner,
                addr1,
                addr2,
                addr3,
            } = statusCache;

            await LpPoolContract.connect(addr2).addLiquidity(
                addr2.address,
                0,
                convertUnit("500", 6),
                1
            );

            const afterBalance = await USDC.balanceOf(addr2.address);
            const addr1LpPosition = await LpPoolContract.getLpPosition(addr2.address);
            const margin = addr1LpPosition[0]
            const notionalEntryAmount = addr1LpPosition[1]
            const lpPositionSize = addr1LpPosition[2]

            expect(afterBalance).to.equal(
                convertUnit("999900", 6)
            );
            expect(margin).to.equal(
                convertUnit("99", 6)
            );
            expect(notionalEntryAmount).to.equal(
                convertUnit("1000", 6)
            );
            expect(lpPositionSize).to.equal(
                convertUnit("1000", 18)
            );

            statusCache = {
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
        });
    });

    describe("Remove LP Liquidity", async function () {
        it("Only remove margin", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionManagerContract,
                owner,
                addr1,
                addr2,
                addr3,
            } = statusCache;

            const amountToWithdraw = convertUnit("100", 6)

            await LpPoolContract.connect(addr1).removeLiquidity(
                addr1.address,
                amountToWithdraw,
                0, // unit is lp token
                1
            )

            const afterBalance = await USDC.balanceOf(addr1.address);

            const addr1LpPosition = await LpPoolContract.getLpPosition(addr1.address);
            const margin = addr1LpPosition[0]
            const notionalEntryAmount = addr1LpPosition[1]
            const lpPositionSize = addr1LpPosition[2]

            expect(afterBalance).to.equal(
                convertUnit("999900", 6)
            );
            expect(margin).to.equal(
                convertUnit("99.5", 6)
            );
            expect(notionalEntryAmount).to.equal(
                convertUnit("500", 6)
            );
            expect(lpPositionSize).to.equal(
                convertUnit("500", 18)
            );


        });

        it("Only remove position", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionManagerContract,
                owner,
                addr1,
                addr2,
                addr3,
            } = statusCache;

            const amountToClose = convertUnit("500", 18)

            const addr1LpPosition1 = await LpPoolContract.getLpPosition(addr1.address);
            const margin1 = addr1LpPosition1[0]
            const notionalEntryAmount1 = addr1LpPosition1[1]
            const lpPositionSize1 = addr1LpPosition1[2]
            console.log(margin1.toString(), notionalEntryAmount1.toString(), lpPositionSize1.toString())

            await LpPoolContract.connect(addr1).removeLiquidity(
                addr1.address,
                0,
                amountToClose, // unit is lp token
                1
            )

            const addr1LpPosition = await LpPoolContract.getLpPosition(addr1.address);
            const margin = addr1LpPosition[0]
            const notionalEntryAmount = addr1LpPosition[1]
            const lpPositionSize = addr1LpPosition[2]

            expect(margin).to.equal(
                convertUnit("99", 6)
            );
            expect(notionalEntryAmount).to.equal(
                convertUnit("0", 6)
            );
            expect(lpPositionSize).to.equal(
                convertUnit("0", 18)
            );

            statusCache = {
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
        });
    });
});
