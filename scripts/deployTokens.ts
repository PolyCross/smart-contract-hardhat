import { ethers } from "hardhat";

async function main() {
  const tokenA = await ethers.deployContract("TestToken", ["Token A", "TA"]);

  await tokenA.waitForDeployment();

  console.log(`The TokenA contract deployed to ${tokenA.target}`);

  const tokenB = await ethers.deployContract("TestToken", ["Token B", "TB"]);

  await tokenB.waitForDeployment();

  console.log(`The tokenB contract deployed to ${tokenB.target}`);

  const tokenC = await ethers.deployContract("TestToken", ["Token C", "TC"]);

  await tokenC.waitForDeployment();

  console.log(`The tokenC contract deployed to ${tokenC.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
