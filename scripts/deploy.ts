import { ethers } from "hardhat";

function delay(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
    const [owner] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("USDC");

    const USDC = await Token.deploy();
    await USDC.deployed();
    await delay(3000);
    await USDC.mint(owner.address, ethers.utils.parseUnits("10000000", 18));
    console.log("check");
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const PriceOracleContract = await PriceOracle.deploy({});
    await PriceOracleContract.deployed();
    console.log("check");
    await delay(3000);
    await PriceOracleContract.addMarket("NFT1");
    await delay(3000);
    await PriceOracleContract.addMarket("NFT2");
    await delay(3000);
    await PriceOracleContract.addMarket("NFT3");
    console.log("addMarkets");
    await delay(3000);
    await PriceOracleContract.setPriceOracle(0, 1000 * 10 ** 9);
    await delay(3000);
    await PriceOracleContract.setPriceOracle(1, 2000 * 10 ** 9);
    await delay(3000);
    await PriceOracleContract.setPriceOracle(2, 3000 * 10 ** 9);
    console.log("set default price");

    const Factory = await ethers.getContractFactory("Factory");
    await delay(3000);
    const FactoryContract = await Factory.deploy();
    await FactoryContract.deployed();
    console.log("factory deployed");
    await delay(3000);
    await FactoryContract.setPriceOracle(PriceOracleContract.address);
    console.log("set price oracle");
    await delay(3000);
    await FactoryContract.createLpPool(USDC.address);
    console.log("create lp pool");
    await delay(3000);
    await FactoryContract.createFeePot();
    console.log("create fee pot");

    const lpPoolAddress = await FactoryContract.getLpPool();
    const feePotAddress = await FactoryContract.getFeePot();
    const LpPool = await ethers.getContractFactory("LpPool");
    const LpPoolContract = LpPool.attach(lpPoolAddress);
    console.log("check");
    await delay(3000);
    await LpPoolContract.setFeeTier(30, 0);
    await delay(3000);
    await LpPoolContract.setFeeTier(10, 1);
    console.log("setFee");

    const PositionController = await ethers.getContractFactory(
        "PositionController"
    );
    console.log("PC deploy start");
    await delay(3000);
    const PositionControllerContract = await PositionController.deploy(
        FactoryContract.address,
        USDC.address,
        lpPoolAddress
    );
    await PositionControllerContract.deployed();
    console.log("PC deployed");
    await delay(3000);
    await PositionControllerContract.addMarket("NFT1", 20 * 10 ** 2, 500);
    await delay(3000);
    await PositionControllerContract.addMarket("NFT2", 20 * 10 ** 2, 500);
    await delay(3000);
    await PositionControllerContract.addMarket("NFT3", 20 * 10 ** 2, 500);
    console.log("add markets to PC");
    await delay(3000);
    await FactoryContract.setPositionController(
        PositionControllerContract.address
    );
    console.log("set pc to fac");

    const FeePot = await ethers.getContractFactory("FeePot");
    const FeePotContract = FeePot.attach(feePotAddress);
    //await USDC.approve(lpPoolAddress, ethers.utils.parseUnits("100000000", 18));
    console.log(
        USDC.address,
        PriceOracleContract.address,
        FactoryContract.address,
        LpPoolContract.address,
        PositionControllerContract.address,
        FeePotContract.address
    );
    return {
        USDC,
        PriceOracleContract,
        FactoryContract,
        LpPoolContract,
        PositionControllerContract,
        FeePotContract,
    };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
