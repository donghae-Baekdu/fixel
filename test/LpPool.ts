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
        await USDC.mint(owner.address, ethers.utils.parseUnits("1000000", 18));
        await USDC.mint(addr1.address, ethers.utils.parseUnits("1000000", 18));
        await USDC.mint(addr2.address, ethers.utils.parseUnits("1000000", 18));
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
        await LpPoolContract.setFeeTier(30, 0);
        await LpPoolContract.setFeeTier(10, 1);

        const FeePot = await ethers.getContractFactory("FeePot");
        const FeePotContract = await FeePot.attach(feePotAddress);

        const PositionController = await ethers.getContractFactory(
            "PositionController"
        );
        const PositionControllerContract = await PositionController.attach(
            positionControllerAddress
        );

        await USDC.connect(owner).approve(LpPoolContract.address, convertUnit("100000000", 18));
        await USDC.connect(addr1).approve(LpPoolContract.address, convertUnit("100000000", 18));
        await USDC.connect(addr2).approve(LpPoolContract.address, convertUnit("100000000", 18));
        await USDC.connect(addr3).approve(LpPoolContract.address, convertUnit("100000000", 18));

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

    function convertUnit(value: string, decimals: number) {
        return ethers.utils.parseUnits(value, decimals);
    }

    let statusCache: any;

    describe("Add Liquidity", async function () {
        it("Initial Add Liquidity", async function () {
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

            await LpPoolContract.connect(addr1).addLiquidity(addr1.address, convertUnit("100", 18), 1)

            expect(await LpPoolContract.balanceOf(addr1.address)).to.equal(convertUnit("99.9", 18))
            expect(await USDC.balanceOf(addr1.address)).to.equal(convertUnit("999900", 18))
            expect(await USDC.balanceOf(LpPoolContract.address)).to.equal(convertUnit("99.97", 18))

            statusCache = {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionControllerContract,
                FeePotContract,
                owner, addr1, addr2, addr3
            }
        });

        it("Additional Add Liquidity", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionControllerContract,
                FeePotContract,
                owner, addr1, addr2, addr3
            } =
                statusCache;

            await LpPoolContract.connect(addr2).addLiquidity(addr2.address, convertUnit("100", 18), 1)
            expect(await LpPoolContract.balanceOf(addr2.address)).to.equal(convertUnit("99.9", 18).mul(convertUnit("99.9", 18)).div(convertUnit("99.97", 18)))
            expect(await USDC.balanceOf(addr2.address)).to.equal(convertUnit("999900", 18))
            expect(await USDC.balanceOf(LpPoolContract.address)).to.equal(convertUnit("99.97", 18).mul("2"))

            statusCache = {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionControllerContract,
                FeePotContract,
                owner, addr1, addr2, addr3
            }
        });
    })

    describe("Remove Liquidity", async function () {
        it("Remove Liquidity", async function () {
            const {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionControllerContract,
                FeePotContract,
                owner, addr1, addr2, addr3
            } =
                statusCache;

            const amountToBurn = convertUnit("50", 18)
            const addr1PrevBalance = await USDC.balanceOf(addr1.address)
            const totalSupply = await LpPoolContract.totalSupply()
            const lockedUSDC = await USDC.balanceOf(LpPoolContract.address)
            const exchangedUSDC = amountToBurn.mul(lockedUSDC).div(totalSupply)
            const withdrewUSDC = exchangedUSDC.mul("999").div("1000")
            const deltaLocked = withdrewUSDC.add(exchangedUSDC.sub(exchangedUSDC.mul("9997").div("10000")))

            await LpPoolContract.connect(addr1).removeLiquidity(addr1.address, convertUnit("50", 18), 1)
            expect(await LpPoolContract.balanceOf(addr1.address)).to.equal(convertUnit("49.9", 18))
            expect((await USDC.balanceOf(addr1.address)).sub(addr1PrevBalance)).to.equal(withdrewUSDC)
            expect(lockedUSDC.sub(await USDC.balanceOf(LpPoolContract.address))).to.equal(deltaLocked)
            expect(totalSupply.sub(await LpPoolContract.totalSupply())).to.equal(convertUnit("50", 18))

            statusCache = {
                USDC,
                PriceOracleContract,
                FactoryContract,
                LpPoolContract,
                PositionControllerContract,
                FeePotContract,
                owner, addr1, addr2, addr3
            }
        });
    })

    describe("Revert testing", async function () {
        it("Permission testing", async function () {
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

            await expect(LpPoolContract.connect(addr1).addLiquidity(addr1.address, convertUnit("100", 18), 0)).to.be.revertedWith("Not allowed to add liquidity as a trader")
            await LpPoolContract.connect(addr1).addLiquidity(addr1.address, convertUnit("100", 18), 1)
            await expect(LpPoolContract.connect(addr1).removeLiquidity(addr1.address, convertUnit("10", 18), 0)).to.be.revertedWith("Not allowed to remove liquidity as a trader")
        });
    })
});
