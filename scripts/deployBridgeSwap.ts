import { ethers, upgrades } from "hardhat";

async function main() {
  const BridgeSwap = await ethers.getContractFactory("BridgeSwap");
  const brigeSwap = await upgrades.deployProxy(BridgeSwap);

  await brigeSwap.waitForDeployment();

  console.log(`The Bridge contract deployed to ${brigeSwap.target}`);

  await brigeSwap.Initialize();

  console.log(`The Contract has inited`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
