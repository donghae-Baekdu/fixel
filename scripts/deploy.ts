import { ethers } from "hardhat";

async function main() {
    //const [owner] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const USDC = await Token.deploy();
    await USDC.deployed();
    //await USDC.mint(owner.address, ethers.utils.parseUnits("10000000", 18));
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
    //await USDC.approve(lpPoolAddress, ethers.utils.parseUnits("100000000", 18));
    console.log(USDC.address, PriceOracleContract.address, FactoryContract.address, LpPoolContract.address,PositionControllerContract.address, FeePotContract.address)
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
