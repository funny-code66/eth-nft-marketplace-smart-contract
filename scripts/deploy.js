// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Custom = await hre.ethers.getContractFactory('Custom');
  const custom = await Custom.deploy('NFT', 'NFT');

  await custom.deployed();

  console.log('NFT Contract Address:', custom.address);

  const Addresses = await hre.ethers.getContractFactory('Addresses');
  const addresses = await Addresses.deploy();

  await addresses.deployed();

  console.log('Address Management Contract Address:', addresses.address);

  const Marketplace = await hre.ethers.getContractFactory('ClockSale');
  const marketplace = await Marketplace.deploy();

  await marketplace.deployed();

  console.log('Marketplace Contract Address:', marketplace.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
