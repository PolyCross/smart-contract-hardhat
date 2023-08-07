import { ethers } from "hardhat";

async function main() {
    const bridge = await ethers.deployContract("TestToken");

    await bridge.waitForDeployment();

    console.log(`The Bridge contract deployed to ${bridge.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
