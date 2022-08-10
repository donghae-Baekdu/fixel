import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

interface Args {
  marketId: string;
};
  
task("update-oracle", "Updates an oracle")
.addParam("marketId", "Id of market")
.setAction(async (args: Args, hre: HardhatRuntimeEnvironment) => {
    const { admin } = await hre.getNamedAccounts();
    const { get } = hre.deployments;

    const deployment = await get("PriceOracle");

    const PriceOracleContract = (await hre.ethers.getContractAt(
      deployment.abi,
      deployment.address
    ));

    const adminSigner = await hre.ethers.getSigner(admin);

    const price = 0; // TODO calculate price

    await PriceOracleContract.connect(adminSigner).setPriceOracle(args.marketId, price);
});