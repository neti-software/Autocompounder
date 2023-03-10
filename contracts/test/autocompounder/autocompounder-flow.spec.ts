import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract, Wallet } from "ethers";
import { ethers, waffle, network } from "hardhat";
import web3 from "web3";
import { AutoCompounder, AutoCompounderFactory, Fee, MockUniswapV3Quoter, StakingRewards } from "../../typechain";
import { IERC20 } from "../../typechain/IERC20";
import { IUniswapV2Router02 } from "../../typechain/IUniswapV2Router02";
import { IUniswapV3Pool } from "../../typechain/IUniswapV3Pool";
import { v2Fixture } from "../utils/fixtureUniswapV2";

const { toWei, fromWei } = web3.utils;

async function mineBlocks(blockNumber: number) {
  while (blockNumber > 0) {
    blockNumber--;
    await network.provider.request({
      method: "evm_mine",
      params: [],
    });
  }
}

describe("AutoCompounder - Flow Test", () => {
  let wallets: Wallet[];
  let deployer: Wallet;
  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>;
  let token0: IERC20;
  let token1: IERC20;
  let factoryV2: Contract;
  let router: IUniswapV2Router02;
  let pair: Contract;
  let pool: IUniswapV3Pool;
  let owner: SignerWithAddress;
  let acc1: Wallet;
  let acc2: Wallet;
  let acc3: Wallet;
  let fee: Fee;
  let quoter: MockUniswapV3Quoter;
  let stakingReward: StakingRewards;
  let autocompounderFactory: AutoCompounderFactory;
  let autocompounder: AutoCompounder;
  const deadline = 1926756514;

  before("create fixture loader", async () => {
    wallets = await (ethers as any).getSigners();
    deployer = wallets[0];
    acc1 = wallets[1];
    acc2 = wallets[2];
    acc3 = wallets[3];
    [owner] = await ethers.getSigners();

    // mock quoter
    const quoterDeployer = await ethers.getContractFactory("MockUniswapV3Quoter");
    quoter = (await quoterDeployer.deploy()) as MockUniswapV3Quoter;
  });

  beforeEach(async () => {
    loadFixture = waffle.createFixtureLoader(wallets as any);

    ({ token0, token1, factoryV2, router, pair } = await loadFixture(v2Fixture));

    const feeDeployer = await ethers.getContractFactory("MockFee");
    fee = (await feeDeployer.deploy()) as Fee;

    const stakingRewardDeployer = await ethers.getContractFactory("StakingRewards2");
    stakingReward = (await stakingRewardDeployer.deploy(
      owner.address,
      acc1.address,
      token1.address,
      pair.address
    )) as StakingRewards;

    const autocompounderFactoryDeployer = await ethers.getContractFactory("AutoCompounderFactory");
    autocompounderFactory = (await autocompounderFactoryDeployer.deploy()) as AutoCompounderFactory;

    // set factory address
    await autocompounderFactory.setUniswapV2Factory(factoryV2.address);

    // create autocompounder for farm
    const autocompounderAddr = await autocompounderFactory.callStatic.createAutoCompounder(
      fee.address,
      stakingReward.address, // farming pool
      router.address, // router
      1, // single reward type
      token1.address, // TEST - RewardToken
      ethers.constants.AddressZero, 
      ethers.constants.AddressZero,
      {
        gasLimit: 30000000,
      }
    );

    await autocompounderFactory.createAutoCompounder(
      fee.address,
      stakingReward.address, // farming pool
      router.address, // router
      1, // single reward type
      token1.address, // TEST - RewardToken
      ethers.constants.AddressZero, 
      ethers.constants.AddressZero,
      {
        gasLimit: 30000000,
      }
    );

    autocompounder = (await ethers.getContractAt("AutoCompounder", autocompounderAddr)) as AutoCompounder;
    // transfer to fake reward
    await token0.transfer(stakingReward.address, toWei("10000000"));
    await token1.transfer(stakingReward.address, toWei("10000000"));

    // approve
    await token0.approve(autocompounder.address, ethers.constants.MaxUint256);
    await token1.approve(autocompounder.address, ethers.constants.MaxUint256);
    await pair.approve(autocompounder.address, ethers.constants.MaxUint256);

    // approve for router and pair
    await token0.approve(router.address, ethers.constants.MaxUint256);
    await token1.approve(router.address, ethers.constants.MaxUint256);
    await token0.approve(pair.address, ethers.constants.MaxUint256);
    await token1.approve(pair.address, ethers.constants.MaxUint256);

    // mint LP token
    await router
      .connect(deployer)
      .addLiquidity(
        token1.address,
        token0.address,
        toWei("5000"),
        toWei("10000"),
        toWei("100"),
        toWei("100"),
        deployer.address,
        deadline
      );
      
      // Move some LP Tokens to Account nr 3.
      await pair.approve(acc3.address, ethers.constants.MaxUint256);
      let LPPAmount = await pair.balanceOf(deployer.address);
      pair.transfer(acc3.address, LPPAmount.div(2));
  });


  it("deposit, farm and withdraw - Deployer Account", async () => {
    // get UBE token amount
    const beforeUBEAmount = await token1.callStatic.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m", "->before TEST - RewardToken Amount", fromWei(beforeUBEAmount.toString()));

    const amountLPacc1 = await pair.callStatic.balanceOf(deployer.address);
    console.log("amountLP on Acc1:", fromWei(amountLPacc1.toString()));

    const amountLPAcc3 = await pair.callStatic.balanceOf(acc3.address);
    console.log("amountLP on Acc3:", fromWei(amountLPAcc3.toString()));

    await autocompounder.deposit(toWei("100"), deployer.address);

    const amountLPafter = await pair.callStatic.balanceOf(deployer.address);
    console.log("amountLP After depo:", fromWei(amountLPafter.toString()));

    const checkEarned = await stakingReward.callStatic.earned(autocompounder.address);
    console.log("\x1b[36m%s\x1b[0m","Staking Rewards:", fromWei(checkEarned.toString()));
    await mineBlocks(10000);
    const checkEarnedAfterMine = await stakingReward.callStatic.earned(autocompounder.address);
    console.log("\x1b[36m%s\x1b[0m","Staking Rewards After 10000 Blocks:", fromWei(checkEarnedAfterMine.toString()));
    await autocompounder.claimAndFarm();
    await autocompounder.claimAndFarm();

    const acc1AfterALP = await autocompounder.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m","ALP Tokens:", fromWei(acc1AfterALP.toString()));
    // get LP token amount
    await autocompounder.withdraw(deployer.address, await autocompounder.balanceOf(deployer.address));

    // get UBE token amount
    const afterUBEAmount = await token1.callStatic.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m", "after TEST - RewardToken Amount", fromWei(afterUBEAmount.toString()));
  });



  it("deposit, farm and withdraw - More Accounts", async () => {
    //Approve Acc1 and Acc2 for LP Split
    await pair.approve(acc2.address, ethers.constants.MaxUint256);
    const LPPAmount1 = await pair.balanceOf(deployer.address);
    pair.transfer(acc2.address, LPPAmount1.div(2));
    const TTAM = await pair.balanceOf(deployer.address);
    token1.transfer(acc2.address, TTAM.div(2));
    const beforeUBEAmount = await token1.callStatic.balanceOf(deployer.address);
    console.log("\x1b[31m%s\x1b[0m", "before TEST - RewardToken Amount - Deployer", fromWei(beforeUBEAmount.toString()));

    const beforeUBEAmountAcc2 = await token1.callStatic.balanceOf(acc2.address);
    console.log("\x1b[31m%s\x1b[0m", "before TEST - RewardToken Amount - Acc 2", fromWei(beforeUBEAmountAcc2.toString()));

    const beforeUBEAmountAcc3 = await token1.callStatic.balanceOf(acc3.address);
    console.log("\x1b[31m%s\x1b[0m", "before TEST - RewardToken Amount - Acc 3", fromWei(beforeUBEAmountAcc3.toString()));

    const feeContractToken0BalanceBefore = await token1.balanceOf(fee.address);
    console.log(
      "\x1b[36m%s\x1b[0m",
      "feeContract Balance Before: ",
      fromWei(feeContractToken0BalanceBefore.toString())
    );

    const amountLPacc = await pair.callStatic.balanceOf(deployer.address);
    console.log("amountLP on deployer:", fromWei(amountLPacc.toString()));

    const amountLPAcc2 = await pair.callStatic.balanceOf(acc3.address);
    console.log("amountLP on Acc2:", fromWei(amountLPAcc2.toString()));

    const amountLPAcc3 = await pair.callStatic.balanceOf(acc3.address);
    console.log("amountLP on Acc3:", fromWei(amountLPAcc3.toString()));

    await autocompounder.deposit(toWei("1700"), deployer.address);

    const amountLPafter = await pair.callStatic.balanceOf(deployer.address);
    console.log("amountLP After depo:", fromWei(amountLPafter.toString()));

    const checkEarned = await stakingReward.callStatic.earned(autocompounder.address);
    console.log("\x1b[36m%s\x1b[0m","Staking Rewards:", fromWei(checkEarned.toString()));
    const deployerAfterALP = await autocompounder.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m","ALP Tokens:", fromWei(deployerAfterALP.toString()));
    // Mine 20k Blocks
    await mineBlocks(20000);
    const checkEarnedAfterMine = await stakingReward.callStatic.earned(autocompounder.address);
    console.log("\x1b[36m%s\x1b[0m","Staking Rewards After 20000 Blocks:", fromWei(checkEarnedAfterMine.toString()));
    await autocompounder.claimAndFarm();
    // Acc2 Deposits
    await autocompounder.deposit(toWei("10"), acc2.address);
    //Mine Extra 1k Blocks
    await mineBlocks(1000);
    await autocompounder.claimAndFarm();
    const acc2AfterALP = await autocompounder.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m","ALP Tokens Increase (After extra 1k blocks):", fromWei(acc2AfterALP.toString()));
    await autocompounder.claimAndFarm();
    await autocompounder.claimAndFarm();
    const acc1AfterALP = await autocompounder.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m","ALP Tokens End:", fromWei(acc1AfterALP.toString()));
    await autocompounder.deposit(toWei("30"), acc3.address);
    await autocompounder.claimAndFarm();
    // get LP token amount
    await autocompounder.withdraw(deployer.address, await autocompounder.balanceOf(deployer.address));
    await autocompounder.claimAndFarm();
    await autocompounder.withdraw(acc3.address, await autocompounder.balanceOf(acc3.address));

    // get UBE token amount
    const afterUBEAmount = await token1.callStatic.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m", "after TEST - RewardToken Amount", fromWei(afterUBEAmount.toString()));
    const afterUBEAmountAcc1 = await token1.callStatic.balanceOf(acc2.address);
    console.log("\x1b[36m%s\x1b[0m", "after TEST - RewardToken Amount", fromWei(afterUBEAmountAcc1.toString()));
    const afterUBEAmountAcc2 = await token1.callStatic.balanceOf(acc3.address);
    console.log("\x1b[36m%s\x1b[0m", "after TEST - RewardToken Amount", fromWei(afterUBEAmountAcc2.toString()));

    const feeContractToken0BalanceAfter = await token1.balanceOf(fee.address);
    console.log(
      "\x1b[36m%s\x1b[0m",
      "feeContract Balance After:",
      fromWei(feeContractToken0BalanceAfter.toString())
    );
  });
});
