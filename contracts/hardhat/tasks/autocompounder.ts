import {IERC20__factory} from "./../../typechain/factories/IERC20__factory";
import {AutoCompounderFactory__factory} from "./../../typechain/factories/AutoCompounderFactory__factory";
import {task} from "hardhat/config";

const ROUTER = "0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121";

// task 1
task("init:autocompounder-factory").setAction(async (_, hre) => {
  const {deployments, ethers, getChainId} = hre;
  const [deployer] = await ethers.getSigners();

  const AutoCompounderFactoryContract = await deployments.get("AutoCompounderFactory");

  const autoCompounderFactoryInstance = (
    await AutoCompounderFactory__factory.connect(AutoCompounderFactoryContract.address, ethers.provider)
  ).connect(deployer);
  const tx = await autoCompounderFactoryInstance.setUniswapV2Factory("0x62d5b84be28a183abb507e125b384122d2c25fae", {
    gasLimit: 2000000,
  });

  console.log("\x1b[36m%s\x1b[0m", "tx", tx);
});

// task 2
task("create:autocompounder")
  .addOptionalParam("farmingPoolAddress")
  .addOptionalParam("type")
  .addOptionalParam("token1")
  .addOptionalParam("token2")
  .addOptionalParam("token3")
  .setAction(async (taskArgs, hre) => {
    const {deployments, ethers, getChainId} = hre;
    const [deployer] = await ethers.getSigners();

    const {farmingPoolAddress, token1, token2, token3, type} = taskArgs;
    const AutocompounderFactoryContract = await deployments.get("AutoCompounderFactory");
    const feeAddress = (await deployments.get("Fee")).address;

    const autoCompounderFactoryInstance = await AutoCompounderFactory__factory.connect(
      AutocompounderFactoryContract.address,
      ethers.provider
    );

    console.log("\x1b[36m%s\x1b[0m", "AutocompounderFactoryContract", AutocompounderFactoryContract.address);
    console.log("\x1b[36m%s\x1b[0m", "farmingPoolAddress", farmingPoolAddress);
    console.log("\x1b[36m%s\x1b[0m", "feeAddress", feeAddress);
    console.log("\x1b[36m%s\x1b[0m", "token1", token1);
    console.log("\x1b[36m%s\x1b[0m", "token2", token2 || ethers.constants.AddressZero);
    console.log("\x1b[36m%s\x1b[0m", "token3", token3 || ethers.constants.AddressZero);

    let tx: any = await autoCompounderFactoryInstance.connect(deployer).createAutoCompounder(
      feeAddress,
      farmingPoolAddress, // farming pool
      ROUTER, // router
      type, // triple reward type
      token1, // UBE
      token2 || ethers.constants.AddressZero,
      token3 || ethers.constants.AddressZero,
    );
    console.log("\x1b[36m%s\x1b[0m", "tx", tx);
    tx = await tx.wait();

    const autoCompounderAddress = tx.events[tx.events.length - 1].args.autoCompounder;
    console.log("\x1b[36m%s\x1b[0m", "autoCompounderAddress", autoCompounderAddress);
  });

// sample task
task("create:sample").setAction(async (taskArgs, hre) => {
  const {deployments, ethers, getChainId} = hre;
  const [deployer] = await ethers.getSigners();

  const AutocompounderFactoryContract = await deployments.get("AutoCompounderFactory");
  const chainId = await getChainId();

  const autoCompounderFactoryInstance = await AutoCompounderFactory__factory.connect(
    AutocompounderFactoryContract.address,
    ethers.provider
  );
  const feeAddress = (await deployments.get("Fee")).address;

  // 0x9D87c01672A7D02b2Dc0D0eB7A145C7e13793c3B UBE - CELO double rewards
  let tx: any = await autoCompounderFactoryInstance.connect(deployer).createAutoCompounder(
    feeAddress,
    "0xcca933D2ffEDCa69495435049a878C4DC34B079d", // farming pool
    ROUTER, // router
    1,
    "0x00Be915B9dCf56a3CBE739D9B9c202ca692409EC",
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
    {
      gasLimit: 3000000,
    }
  );
  console.log("\x1b[36m%s\x1b[0m", "tx", tx);
  tx = await tx.wait();

  console.log("\x1b[36m%s\x1b[0m", "tx.events", tx.events);

  const autoCompounderAddress = tx.events[tx.events.length - 1].args.autoCompounder;
  console.log("\x1b[36m%s\x1b[0m", "autoCompounderAddress", autoCompounderAddress);
});
