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

describe("AutoCompounder - Single Reward", () => {
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
  const deadline = 1726756514;

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
      token1.address, // UBE
      ethers.constants.AddressZero, // CELO
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
      token1.address, // UBE
      ethers.constants.AddressZero, // CELO
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
        toWei("1000"),
        toWei("5000"),
        toWei("100"),
        toWei("100"),
        deployer.address,
        deadline
      );
      
      // Move some LP Tokens to 3 Account.
      await pair.approve(acc3.address, ethers.constants.MaxUint256);
      const LPPAmount = await pair.balanceOf(deployer.address);
      pair.transfer(acc3.address, LPPAmount.div(2));
  });

  it("deposit, farm and withdraw", async () => {
    // get UBE token amount
    const beforeUBEAmount = await token1.callStatic.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m", "beforeUBEAmount", fromWei(beforeUBEAmount.toString()));

    const amountLPacc1 = await pair.callStatic.balanceOf(deployer.address);
    console.log("amountLP on Acc1:", fromWei(amountLPacc1.toString()));

    const amountLPAcc3 = await pair.callStatic.balanceOf(acc3.address);
    console.log("amountLP on Acc3:", fromWei(amountLPAcc3.toString()));

    await autocompounder.deposit(toWei("100"), deployer.address);

    const amountLPafter = await pair.callStatic.balanceOf(deployer.address);
    console.log("amountLP After depo:", fromWei(amountLPafter.toString()));

    const checkEarned = await stakingReward.callStatic.earned(autocompounder.address);
    console.log("Staking Rewards:", fromWei(checkEarned.toString()));
    await mineBlocks(10000);
    const checkEarnedAfterMine = await stakingReward.callStatic.earned(autocompounder.address);
    console.log("Staking Rewards After 10000 Blocks:", fromWei(checkEarnedAfterMine.toString()));
    await autocompounder.claimAndFarm();
    // get LP token amount
    await autocompounder.withdraw(deployer.address, await autocompounder.balanceOf(deployer.address));

    // get UBE token amount
    const afterUBEAmount = await token1.callStatic.balanceOf(deployer.address);
    console.log("\x1b[36m%s\x1b[0m", "afterUBEAmount", fromWei(afterUBEAmount.toString()));
  });

  it("deposit", async () => {
    await expect(autocompounder.claim(deployer.address)).to.not.reverted;
    // get LP token amount
    const amountLP = await pair.callStatic.balanceOf(deployer.address);
    console.log("🚀 ~ file: autocompounder.spec.ts ~ line 135 ~ it ~ amountLP", fromWei(amountLP.toString()));
    // allowance
    const allowance = await pair.callStatic.allowance(deployer.address, autocompounder.address);
    console.log("🚀 ~ file: autocompounder.spec.ts ~ line 153 ~ it ~ allowance", fromWei(allowance.toString()));
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    await autocompounder.deposit(toWei("1"), deployer.address);

    await autocompounder.claimAndFarm();
    // get LP token amount
    const ALPAmount = await autocompounder.balanceOf(deployer.address);
    console.log("🚀 ~ file: autocompounder.spec.ts ~ line 154 ~ it ~ ALPAmount", fromWei(ALPAmount.toString()));
    await autocompounder.claimAndFarm();
    await autocompounder.withdraw(deployer.address, ALPAmount);
    const amountLPAfter = await pair.callStatic.balanceOf(deployer.address);
    console.log("🚀 ~ file: autocompounder.spec.ts ~ line 168 ~ it ~ amountLPAfter", fromWei(amountLPAfter.toString()));
  });

  it("withdraw", async () => {
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    await autocompounder.deposit(toWei("1"), deployer.address);

    await autocompounder.claimAndFarm();

    const amount = await stakingReward.balanceOf(autocompounder.address);
    console.log("\x1b[36m%s\x1b[0m", "amount", fromWei(amount.toString()));
    await autocompounder.withdraw(deployer.address, toWei("5"));

    // get LP token amount
    const ALPAmount = await autocompounder.balanceOf(deployer.address);
    console.log("🚀 ~ file: autocompounder.spec.ts ~ line 154 ~ it ~ ALPAmount", fromWei(ALPAmount.toString()));
    await autocompounder.withdraw(deployer.address, ALPAmount);
  });

  it("claim rewards", async () => {
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    await autocompounder.deposit(toWei("1"), deployer.address);

    await autocompounder.claimAndFarm();
    const beforeAmount = await token1.balanceOf(deployer.address);
    await autocompounder.claim(deployer.address);
    const afterAmount = await token1.balanceOf(deployer.address);
    expect(Number(fromWei(afterAmount.toString()))).to.be.greaterThan(Number(fromWei(beforeAmount.toString())));
  });

  it("withdraw - revert with reason NEA and NP", async () => {
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    await autocompounder.deposit(toWei("1"), deployer.address);

    const ALPAmount = await autocompounder.balanceOf(deployer.address);

    await expect(
      autocompounder.withdraw(deployer.address, ALPAmount.add(ethers.BigNumber.from("10")))
    ).to.be.revertedWith("AC: NEA");
  });

  it("setting stats", async () => {
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    const ALPAmount = await autocompounder.balanceOf(deployer.address);

    await expect(
      autocompounder.withdraw(deployer.address, ALPAmount.add(ethers.BigNumber.from("10")))
    ).to.be.revertedWith("AC: NEA");

    await autocompounder.emergencyWithdraw(deployer.address, await autocompounder.firstRewardAddress());
    await autocompounder.setFeeAddress(fee.address);
    await autocompounder.setFirstRewardAddress(token0.address);
    await autocompounder.setSecondRewardAddress(token0.address);
    await autocompounder.setThirdRewardAddress(token0.address);
    await autocompounder.setFarmingPoolType(1);
    await autocompounder.setUniswapV2Router(router.address);
    await fee.collectFee(deployer.address, token0.address);

    expect(await autocompounder.feeContract()).to.be.equal(fee.address);
    expect(await autocompounder.firstRewardAddress()).to.be.equal(token0.address);
    expect(await autocompounder.secondRewardAddress()).to.be.equal(token0.address);
    expect(await autocompounder.thirdRewardAddress()).to.be.equal(token0.address);
    expect(await autocompounder.uniswapV2Router()).to.be.equal(router.address);
    expect(await autocompounder.farmingPoolType()).to.be.equal(1);
  });

  it("setting stats - not admin role", async () => {
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    const ALPAmount = await autocompounder.balanceOf(deployer.address);

    await expect(
      autocompounder.withdraw(deployer.address, ALPAmount.add(ethers.BigNumber.from("10")))
    ).to.be.revertedWith("AC: NEA");

    await expect(
      autocompounder.connect(acc2).emergencyWithdraw(deployer.address, await autocompounder.firstRewardAddress())
    ).to.be.revertedWith("AC: ADR");
    await expect(autocompounder.connect(acc2).setFeeAddress(fee.address)).to.be.revertedWith("AC: ADR");
    await expect(autocompounder.connect(acc2).setFirstRewardAddress(fee.address)).to.be.revertedWith("AC: ADR");
    await expect(autocompounder.connect(acc2).setSecondRewardAddress(fee.address)).to.be.revertedWith("AC: ADR");
    await expect(autocompounder.connect(acc2).setThirdRewardAddress(fee.address)).to.be.revertedWith("AC: ADR");
    await expect(autocompounder.connect(acc2).setFarmingPoolType(1)).to.be.revertedWith("AC: ADR");
    await expect(autocompounder.connect(acc2).setUniswapV2Router(fee.address)).to.be.revertedWith("AC: ADR");

    await expect(fee.connect(acc2).collectFee(deployer.address, token0.address)).to.be.reverted;
  });

  it("deposit 0", async () => {
    await autocompounder.deposit(toWei("0"), deployer.address);
  });

  it("autocompounder name", async () => {
    const token0Name = await token0.symbol();
    const token1Name = await token1.symbol();
    const expectedName = `${token0Name}-${token1Name}-1 AutoCompounder LP Token`;
    const expectedSymbol = `${token0Name}-${token1Name}-1 ALP`;

    expect(await autocompounder.name()).to.be.equal(expectedName);
    expect(await autocompounder.symbol()).to.be.equal(expectedSymbol);
  });

  it("should transfer fee to fee contract", async () => {
    const feeContractToken0BalanceBefore = await token1.balanceOf(fee.address);
    console.log(
      "\x1b[36m%s\x1b[0m",
      "feeContractToken0BalanceBefore",
      fromWei(feeContractToken0BalanceBefore.toString())
    );

    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    await autocompounder.deposit(toWei("1"), deployer.address);

    await autocompounder.claimAndFarm();
    const beforeAmount = await token1.balanceOf(deployer.address);
    await autocompounder.claim(deployer.address);
    const afterAmount = await token1.balanceOf(deployer.address);

    const feeContractToken0BalanceAfter = await token1.balanceOf(fee.address);
    console.log(
      "\x1b[36m%s\x1b[0m",
      "feeContractToken0BalanceAfter",
      fromWei(feeContractToken0BalanceAfter.toString())
    );
    await fee.collectFee(deployer.address, token1.address);
    expect(Number(fromWei(feeContractToken0BalanceAfter.toString()))).to.be.greaterThan(
      Number(fromWei(feeContractToken0BalanceBefore.toString()))
    );
    expect(Number(fromWei(afterAmount.toString()))).to.be.greaterThan(Number(fromWei(beforeAmount.toString())));
  });

  context("With ALP Token", () => {
    beforeEach(async () => {
      // deposit 100
      await autocompounder.deposit(toWei("100"), deployer.address);

      await autocompounder.deposit(toWei("1"), deployer.address);
    });

    it("should not withdraw", async () => {
      // get LP token amount
      const ALPAmount = await autocompounder.balanceOf(deployer.address);
      await expect(autocompounder.withdraw(deployer.address, ALPAmount.mul(2))).to.be.revertedWith("AC: NEA");
    });

    it("should transfer ALP", async () => {
      const acc1BeforeALP = await autocompounder.balanceOf(acc1.address);
      expect(acc1BeforeALP).to.be.equal(toWei("0"));

      const ALPAmount = await autocompounder.balanceOf(deployer.address);
      await autocompounder.transfer(acc1.address, ALPAmount.div(2));

      const acc1AfterALP = await autocompounder.balanceOf(acc1.address);
      expect(acc1AfterALP).to.be.equal(ALPAmount.div(2));
    });

    it("should transferFrom ALP", async () => {
      const acc1BeforeALP = await autocompounder.balanceOf(acc1.address);
      expect(acc1BeforeALP).to.be.equal(toWei("0"));

      const ALPAmount = await autocompounder.balanceOf(deployer.address);
      await autocompounder.approve(acc1.address, ALPAmount);
      const allowance = await autocompounder.allowance(deployer.address, acc1.address);
      expect(allowance).to.be.equal(ALPAmount);

      await autocompounder.connect(acc1).transferFrom(deployer.address, acc1.address, ALPAmount.div(2));

      const acc1AfterALP = await autocompounder.balanceOf(acc1.address);
      expect(acc1AfterALP).to.be.equal(ALPAmount.div(2));
    });

    it("should not mint to zero address", async () => {
      await expect(autocompounder.deposit(toWei("1"), ethers.constants.AddressZero)).to.be.revertedWith(
        "MINT_TO_THE_ZERO_ADDRESS"
      );

      const ALPAmount = await autocompounder.balanceOf(deployer.address);
      await expect(autocompounder.transfer(ethers.constants.AddressZero, ALPAmount.div(2))).to.be.revertedWith(
        "TRANSFER_TO_THE_ZERO_ADDRESS"
      );
    });

    it("should not transfer exceeds balance", async () => {
      await expect(autocompounder.deposit(toWei("1"), ethers.constants.AddressZero)).to.be.revertedWith(
        "MINT_TO_THE_ZERO_ADDRESS"
      );

      const ALPAmount = await autocompounder.balanceOf(deployer.address);
      await expect(autocompounder.transfer(acc1.address, ALPAmount.mul(2))).to.be.revertedWith(
        "TRANSFER_AMOUNT_EXCEEDS_BALANCE"
      );
    });
  });
});
