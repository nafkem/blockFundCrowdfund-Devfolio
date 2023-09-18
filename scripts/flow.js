// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { time} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

async function main() {
  const [deployer, donator1, donator2] = await hre.ethers.getSigners();

  //----------------Deploying the contract----------------//

//deploying the nft contract
  const FundBlockNFT = await hre.ethers.deployContract("FundBlockNFT");

  await FundBlockNFT.waitForDeployment();

  console.log(`FundBlockNFT deployed to ${FundBlockNFT.target}`);

// deploying the FundBlock contract
  const FundBlock = await hre.ethers.deployContract("FundBlock", [FundBlockNFT.target]);

  await FundBlock.waitForDeployment();

  console.log(`FundBlock deployed to ${FundBlock.target}`);


  //----------------Interacting with the contract----------------//
  const FundBlockNFTContract = await hre.ethers.getContractAt("FundBlockNFT", FundBlockNFT.target);
  const transferOwnership = await FundBlockNFTContract.transferOwnership(FundBlock.target);


      //create campaign//
  const FundBlockContract = await hre.ethers.getContractAt("FundBlock", FundBlock.target);
  const amountobeDonated = hre.ethers.parseEther("10.0");
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;

  const createCampaign = await FundBlockContract.createCampaign("Campaign 1", "This is the first campaign", amountobeDonated, ONE_YEAR_IN_SECS, "linktothefile");
  const createCampaignReceipt = await createCampaign.wait();
  console.log("createCampaign transaction receipt: ", createCampaignReceipt.provider);

  // // update campaign details (only the creator can do this)
  // const updateCampaign = await FundBlockContract.connect(donator1).updateCampaignDetails(0, "This is the first campaign", "linktothefile");
  // const updateCampaignReceipt = await updateCampaign.wait();
  // console.log("updateCampaign transaction receipt: ", updateCampaignReceipt);

// donate to campaign//
const Amount = hre.ethers.parseEther("5.0");
const Amount2 = hre.ethers.parseEther("2.0");


  const donateToCampaign = await FundBlockContract.connect(donator1).donateToCampaign(0,{value: Amount,} );
  const donateToCampaignReceipt = await donateToCampaign.wait();
  console.log("donateToCampaign transaction receipt: ", donateToCampaignReceipt);

  await FundBlockContract.connect(donator2).donateToCampaign(0,{value: Amount,} );
//   await FundBlockContract.connect(deployer).donateToCampaign(0,{value: Amount,} );

  ///--------miscellaneous--------///

  const getDonordetails = await FundBlockContract.donorsDetails(donator1.address, 0);
  console.log("getDonordetails: ", getDonordetails);



  //---get cmapaigns-------//
  const getDonors = await FundBlockContract.getDonors(0)
  console.log("campaign donors", getDonors)



  //-----------withdrawDonationsForACampaign ----//
  const withdrawDonationsForACampaign = await FundBlockContract.withdrawDonationsForACampaign(0);
  const withdrawDonationsForACampaignReceipt = await withdrawDonationsForACampaign.wait();
  console.log("withdrawDonationsForACampaign transaction receipt: ", withdrawDonationsForACampaignReceipt);

  //==---- claim rewards =======------//
  const claimRewards = await FundBlockContract.connect(donator1).claimRewards(0);
  const claimRewardsReceipt = await claimRewards.wait();
  console.log("claimRewards transaction receipt: ", claimRewardsReceipt);


  //check nft bal//
  const nftBal = await FundBlockNFTContract.balanceOf(donator1.address);
  console.log("nftBal: ", nftBal.toString());


  //-----get stataus ------//
  const getCampaignStatus = await FundBlockContract.getCampaignStatus(0);
  console.log("campaign status", getCampaignStatus)


  //get cmapaign//
  const getCampaign = await FundBlockContract.getCampaign(0)
  console.log("campaing details", getCampaign)





}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
