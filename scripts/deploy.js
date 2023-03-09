// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  console.log("start deploy stakingPool ...")
  const stakingPoolFactory = await hre.ethers.getContractFactory("StakingPool");
  const stakingPool = await stakingPoolFactory.deploy();
  console.log("stakingPool address is ", stakingPool.address);

  console.log("start deploy LPEth ...")
  const LPEthFactory = await hre.ethers.getContractFactory("LPEth");
  const LPEth = await LPEthFactory.deploy(stakingPool.address);
  console.log("LPEth address is ", LPEth.address);

  console.log("init stakingPool ...")
  await stakingPool.init(LPEth.address);

  console.log("deploy success");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
