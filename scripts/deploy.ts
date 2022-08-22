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
  await USDC.mint(owner.address, ethers.utils.parseUnits("10000000", 6));
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
  await PriceOracleContract.setPriceOracle(0, 147788.98 * 10 ** 6);
  await delay(3000);
  await PriceOracleContract.setPriceOracle(1, 127214.65 * 10 ** 6);
  await delay(3000);
  await PriceOracleContract.setPriceOracle(2, 29195.74 * 10 ** 6);
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
  const LpPool = await ethers.getContractFactory("LpPool");
  const LpPoolContract = await LpPool.deploy(
    USDC.address,
    FactoryContract.address
  );
  await LpPoolContract.deployed();
  await delay(3000);
  await FactoryContract.setLpPool(LpPoolContract.address);
  await delay(3000);
  const lpPoolAddress = await FactoryContract.getLpPool();
  console.log("check");
  await delay(3000);

  
  await LpPoolContract.setFeeTier(30, false);
  await delay(3000);
  await LpPoolContract.setFeeTier(10, true);
  console.log("setFee");

  const PositionManager = await ethers.getContractFactory("PositionManager");
  console.log("PC deploy start");
  await delay(3000);
  const PositionManagerContract = await PositionManager.deploy(
    FactoryContract.address,
    USDC.address,
    lpPoolAddress
  );
  await PositionManagerContract.deployed();
  console.log("PC deployed");
  await delay(3000);
  await PositionManagerContract.addMarket("NFT1", 20 * 10 ** 2, 500);
  await delay(3000);
  await PositionManagerContract.addMarket("NFT2", 20 * 10 ** 2, 500);
  await delay(3000);
  await PositionManagerContract.addMarket("NFT3", 20 * 10 ** 2, 500);
  console.log("add markets to PC");
  await delay(3000);
  await FactoryContract.setPositionManager(PositionManagerContract.address);
  console.log("set pc to fac");

  //await USDC.approve(lpPoolAddress, ethers.utils.parseUnits("100000000", 18));
  console.log(
    USDC.address,
    PriceOracleContract.address,
    FactoryContract.address,
    LpPoolContract.address,
    PositionManagerContract.address,
  );
console.log(
    `USDC: ${USDC.address}\nPriceOracle: ${PriceOracleContract.address}\nFactory: ${FactoryContract.address}\n
    LpPool: ${LpPoolContract.address}\nPositionManager: ${PositionManagerContract.address}
    `
)

  return {
    USDC,
    PriceOracleContract,
    FactoryContract,
    LpPoolContract,
    PositionManagerContract,
  };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
