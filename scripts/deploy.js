// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {


//deploying the nft contract
  const FundBlockNFT = await hre.ethers.deployContract("FundBlockNFT");

  await FundBlockNFT.waitForDeployment();

  console.log(`FundBlockNFT deployed to ${FundBlockNFT.target}`);

// deploying the FundBlock contract
  const FundBlock = await hre.ethers.deployContract("FundBlock", [FundBlockNFT.target]);

  await FundBlock.waitForDeployment();

  console.log(`FundBlock deployed to ${FundBlock.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
