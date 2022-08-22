# Fixel

![Fixel](resources/Landing.png?raw=true "Title")

The First Perpetual NFT Exchange is Fixel.
Trade CryptoPunk, BAYC, Doodle, and other top NFT collections with up to 20x leverage

# Inspiration
The lack of liquidity in the NFT market limit participants from trading NFTs at the desired size, timing and price. Such liquidity issue occurs due to NFTs’ innate attributes of non-fungibility and indivisibility. There are countless ongoing attempts to tackle such liquidity issue, with representative examples including NFTX which tokenizes NFTs into divisible ERC20 tokens. Nonetheless, NFTX is limited to floor price NFTs and has not been able to solve the liquidity component, thus remaining at a daily total volume of under 100 ETH.

Fixel introduces for the first time three groundbreaking concepts to the NFT market which are (1) Synthetic NFT Exchange; (2) PvP AMM; and (3) Synthetically Leveraged LP to become the First Perpetual NFT Exchange.

# What is Fixel?
Our Perpetual NFT Exchange, Fixel, provides (1) perpetual NFT trades for NFT traders; and (2) leveraged LP for Liquidity Providers.

**(1) Perpetual NFT Trades**

You can trade the average price of an entire NFT collection in the form of perpetual futures with up to 20x leverage. NFT traders can open a long or short position at a desired size, with low fees and without moving the price at all.

- 0.1% Trading Fee (2.5% at OpenSea)
- Zero Slippage
- Leverage up to 20x

**(2) Provide Liquidity with up to 10x Leverage**

Liquidity Providers can provide liquidity to become the counterparty of traders while earning trading fees. Liquidity Providers can make up to a 10x leveraged LP position to maximize fee profit.

- Earn 70% of Fee Distribution
- Liquidity Providing with up to 20x Leverage

#

# How to Install and Run the Project

```
npm install
npx hardhat compile
npx hardhat run scripts/deploy.ts --network <network-name>
```

# Polygon Mainnet contract address

```
USDC(faucet)
0x75C6Bc04462C9cd6917f8FddE5601C07DF647D7F

Oracle
0xd7250e4b3Eb94990D59A19ab65d69365038B6c0e

Factory
0x4aCC327835b7D69365802411D72be01998C64723

LpPool
0x5bC6f2611460df5Ec8eC84Fd4dEB1566b3934eD5

Position Manager
0x85dbe442aB04C0E0Dc76CD91520748433A8d3CDA
```

# .env

```
HARDHAT_NODE_URL=
DEPLOYER_WALLET_ADDRESS=
DEPLOYER_PRIVATE_KEY=
POLYGON_MUMBAI_NODE_URL=
POLYGON_MAINNET_NODE_URL=
```
