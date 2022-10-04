import { BigNumber } from "bignumber.js";
import * as hre from "hardhat";
import { ActionType } from "hardhat/types";
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

interface Market {
  marketId: string;
  oracleId: string;
  initialMarginFraction: string; // bp
  maintenanceMarginFraction: string; // bp
  decimals: string;
}

interface Collateral {
  tokenAddress: string;
  collateralId: string;
  oracleKey: string;
  weight: string;
  decimals: string;
}

const XUSD_COLLATERAL_ID = '0'
const USDC_COLLATERAL_ID = '1'
const WETH_COLLATERAL_ID = '2'

const BTCUSD_MARKET_ID = '0'
const ETHUSD_MARKET_ID = '1'

const ETH_PRICE_ORACLE_ID = '1'
const BTC_PRICE_ORACLE_ID = '2'

const USDC_ADDRESS = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"
const WETH_ADDRESS = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
const WBTC_ADDRESS = "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"

const ETH_MARKET: Market = {
  marketId: ETHUSD_MARKET_ID,
  oracleId: ETH_PRICE_ORACLE_ID,
  initialMarginFraction: '500',
  maintenanceMarginFraction: '250',
  decimals: '9'
}

const BTC_MARKET = {
  marketId: BTCUSD_MARKET_ID,
  oracleId: BTC_PRICE_ORACLE_ID,
  initialMarginFraction: '500',
  maintenanceMarginFraction: '250',
  decimals: '9'
}

const XUSD_COLLATERAL = {
  tokenAddress: string;
  collateralId: string;
  oracleKey: string;
  weight: string;
  decimals: string;
}

describe("TradePositionManager", async function () {
  let fixture: any;
  async function deployFixture() {
    const [owner, addr1, addr2] = await hre.ethers.getSigners();

    console.log(owner.address);
    console.log(addr1.address);
    console.log(addr2.address);

    const mathUtilFactory = await hre.ethers.getContractFactory("MathUtil");
    const MathUtilContract = await mathUtilFactory.deploy();
    await MathUtilContract.deployed();

    const Admin = await hre.ethers.getContractFactory("Admin");
    const AdminContract = await Admin.deploy();
    await AdminContract.deployed();
    const adminAddress = AdminContract.address;
    console.log("Admin Contract Deployed");

    const LpPositionManager = await hre.ethers.getContractFactory(
      "LpPositionManager",
      { libraries: { MathUtil: MathUtilContract.address } }
    );
    const LpPositionManagerContract = await LpPositionManager.deploy(
      adminAddress
    );
    await LpPositionManagerContract.deployed();
    const lpPositionManagerAddress = LpPositionManagerContract.address;
    await AdminContract.setLpPositionManager(lpPositionManagerAddress);
    console.log(
      "LP Position Manager Deployed; address: ",
      lpPositionManagerAddress
    );

    const TradePositionManager = await hre.ethers.getContractFactory(
      "TradePositionManager",
      { libraries: { MathUtil: MathUtilContract.address } }
    );
    const TradePositionManagerContract = await TradePositionManager.deploy(
      AdminContract.address
    );
    await TradePositionManagerContract.deployed();
    const tradePositionManagerAddress = TradePositionManagerContract.address;
    await AdminContract.setTradePositionManager(tradePositionManagerAddress);
    console.log(
      "Trade Position Manager Deployed; address: ",
      tradePositionManagerAddress
    );

    const Vault = await hre.ethers.getContractFactory("Vault");
    const VaultContract = await Vault.deploy(AdminContract.address);
    await VaultContract.deployed();
    const vaultAddress = TradePositionManagerContract.address;
    await AdminContract.setVault(vaultAddress);
    console.log("Vault Deployed; address: ", vaultAddress);

    const PriceOracle = await hre.ethers.getContractFactory("PriceOracle");
    const PriceOracleContract = await PriceOracle.deploy({});
    await PriceOracleContract.deployed();
    const priceOracleAddress = PriceOracleContract.address;
    await AdminContract.setPriceOracle(priceOracleAddress);
    console.log("Price oracle deployed");

    const XUSD = await hre.ethers.getContractFactory("USD");
    const XUSDContract = await XUSD.deploy(AdminContract.address);
    await XUSDContract.deployed();
    const XUSDAddress = XUSDContract.address;
    await AdminContract.setPriceOracle(XUSDAddress);
    console.log("xUSD deployed");

    await PriceOracleContract.addFeed("ETH");
    await PriceOracleContract.activateFeed(0);
    await PriceOracleContract.setPriceOracle(0, 1000 * 10 ** 9);
    console.log("Set price oracle");

    // TODO add market
    await TradePositionManagerContract.listNewMarket(
      0,
      0,
      500,
      250,
      5
    );

    // TODO add collateral
    await TradePositionManagerContract.listNewCollateral(
      "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
      1,
      0,
      uint32 weight,
      uint8 decimals
    )

    // TODO set fee tier

    // set account; impersonate
    // 0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b; Arbitrum whale

    // 989.262058860328115093 ETH
    // 260,878,182 USDC
    // 65.13 WBTC

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b"], // whale address
    });

    const whaleSigner = await hre.ethers.getSigner(
      "0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b"
    );

    const usdcContract = await hre.ethers.getContractAt(
      "IERC20",
      "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"
    );

    const wethContract = await hre.ethers.getContractAt(
      "IERC20",
      "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
    );

    const wbtcContract = await hre.ethers.getContractAt(
      "IERC20",
      "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"
    );

    /*
    await USDC.connect(owner).approve(
      LpPositionManagerContract.address,
      hre.ethers.utils.parseUnits("100000000", 6)
    );
    await USDC.connect(addr1).approve(
      LpPositionManagerContract.address,
      hre.ethers.utils.parseUnits("100000000", 6)
    );
    await USDC.connect(addr2).approve(
      LpPositionManagerContract.address,
      hre.ethers.utils.parseUnits("100000000", 6)
    );
    await USDC.connect(addr3).approve(
      LpPositionManagerContract.address,
      hre.ethers.utils.parseUnits("100000000", 6)
    );
  
    return {
      USDC,
      PriceOracleContract,
      AdminContract,
      LpPoolContract: LpPositionManagerContract,
      PositionManagerContract: TradePositionManagerContract,
      owner,
      addr1,
      addr2,
      addr3,
    };
    */
  }

  it("load fixture", async () => {
    fixture = await deployFixture();
  });
});
