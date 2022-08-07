import { ethers } from "hardhat";
import axios, {AxiosResponse} from "axios";

async function main() {
    const bluechips: string[] = ['zz'];
    const prices: string[] = [];

    for(let i = 0; i < bluechips.length; i++){
        const bluechip = bluechips[i];
        prices.push(await getPriceFromAPI(bluechip));
    }

    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const priceOracleAddress = '0x';
    const priceOracle = await PriceOracle.attach(priceOracleAddress);

    for(let i = 0; i < prices.length; i++){
        await priceOracle.setPriceOracle(i, prices[i]);
    }
}

async function getPriceFromAPI(assetContract: string): Promise<string> {
    const apiKey = 'zzzz';
    const response: any = await axios({
        method: 'GET',
        url: 'https://api.nftbank.ai/v3/market-status/ethereum/' + assetContract,
        headers: {'x-api-key': apiKey, 'Content-Type': 'application/json'}
    })
    return response.data[0].avg_price_eth;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});