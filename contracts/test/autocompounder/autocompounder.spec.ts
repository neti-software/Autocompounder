import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { assert, expect } from "chai";
import { Contract, Wallet } from "ethers";
import { ethers, waffle, network } from "hardhat";
import web3 from "web3";
import { AutoCompounder, AutoCompounderFactory, Fee, MockUniswapV3Quoter, StakingRewards, UniswapV2Factory, ERC20Token, UniswapV2Pair, UniswapV2Router02 } from "../../typechain";
import { IERC20 } from "../../typechain/IERC20";
import { IUniswapV2Router02 } from "../../typechain/IUniswapV2Router02";
import { IUniswapV3Pool } from "../../typechain/IUniswapV3Pool";
import { v2Fixture } from "../utils/fixtureUniswapV2";
import IUniswapV2Pair from "@uniswap/v2-core/build/IUniswapV2Pair.json";

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

async function deployUniswapV2Factory(deployer: SignerWithAddress) {
  return await (await ethers.getContractFactory("UniswapV2Factory")).deploy(deployer.address) as UniswapV2Factory;
}

async function createERC20Tokens() {
  const erc20Deployer = await ethers.getContractFactory("ERC20Token");
  return await Promise.all([
    erc20Deployer.deploy("Test 1", "TEST1"),
    erc20Deployer.deploy("Test 2", "TEST2"),
    erc20Deployer.deploy("Test 3", "TEST3")
  ]);
}

const assertReverts = async (fxn: any, args: any[]) => {
  try {
    await fxn(args);
    assert(false);
  } catch (e) {
    //
  }
};

const DEADLINE = 1726756514;

describe("AutoCompounder", () => {
  let wallets: SignerWithAddress[];
  let deployer: SignerWithAddress;
  let v2Factory: UniswapV2Factory;
  let v2Router: UniswapV2Router02;
  let fee: Fee;
  let token1: ERC20Token, token2: ERC20Token, token3: ERC20Token, tokenA: ERC20Token, tokenB: ERC20Token;
  let lpToken: UniswapV2Pair;
  let stakingRewards: StakingRewards;
  let autoCompounderFactory: AutoCompounderFactory;
  let autoCompounder: AutoCompounder;

  before("create and initialize required contracts", async () => {
    wallets = await ethers.getSigners();
    [deployer] = wallets;

    // Create Uniswap V2 Factory
    v2Factory = await deployUniswapV2Factory(deployer);

    // Create tokens
    [tokenA, tokenB, token3] = await createERC20Tokens() as [ERC20Token, ERC20Token, ERC20Token];

    // Mint 10000000 of each token for the deployer address
    await Promise.all([
      tokenA.mint(deployer.address, toWei("10000000")),
      tokenB.mint(deployer.address, toWei("10000000")),
      token3.mint(deployer.address, toWei("10000000")),
    ]);

    await v2Factory.createPair(tokenA.address, tokenB.address);
    const pairAddress = await v2Factory.getPair(tokenA.address, tokenB.address);
    lpToken = new Contract(pairAddress, IUniswapV2Pair.abi, ethers.provider).connect(deployer) as UniswapV2Pair;

    const token1Address = await lpToken.token0();
    token1 = tokenA.address === token1Address ? tokenA : tokenB;
    token2 = tokenA.address === token1Address ? tokenB : tokenA;

    // Create Fee contract
    fee = await (await ethers.getContractFactory("Fee")).deploy() as Fee;

    // Create UniswapV2Router
    v2Router = await (await ethers.getContractFactory("UniswapV2Router02")).deploy(v2Factory.address) as UniswapV2Router02;

    await Promise.all([
      token1.connect(deployer).approve(v2Router.address, ethers.constants.MaxUint256),
      token2.connect(deployer).approve(v2Router.address, ethers.constants.MaxUint256)
    ]);

    // Create StakingRewards contract
    stakingRewards = await (await ethers.getContractFactory("contracts/ubeswap/StakingRewards.sol:StakingRewards")).deploy(deployer.address, deployer.address, token3.address, lpToken.address) as StakingRewards;

    // Add liquidity to router
    await v2Router.connect(deployer).addLiquidity(token1.address, token2.address, toWei("10000000"), toWei("10000000"), toWei("10000"), toWei("10000"), deployer.address, DEADLINE)

    // console.log("Balance of LP tokens: ", String(await pair.balanceOf(deployer.address)));

    // Create AutoCompounderFactory
    autoCompounderFactory = await (await ethers.getContractFactory("AutoCompounderFactory")).deploy() as AutoCompounderFactory;
    await autoCompounderFactory.setUniswapV2Factory(v2Factory.address);

    // Create AutoCompounder
    await autoCompounderFactory.createAutoCompounder(
      fee.address,
      stakingRewards.address,
      v2Router.address,
      1,
      token3.address,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero
    );
    const autoCompounderAddress = await autoCompounderFactory.getAutoCompounder(stakingRewards.address);
    autoCompounder = await ethers.getContractAt("AutoCompounder", autoCompounderAddress) as AutoCompounder;
  });

  it('should revert on trying to transfer 10000 LP tokens through AutoCompounder', async () => {
    await assertReverts(autoCompounder.deposit, [toWei("10000"), deployer.address]);
  });

  it('should approve AutoCompounder to transfer tokens in the name of the deployer wallet address', async () => {
    await lpToken.connect(deployer).approve(autoCompounder.address, ethers.constants.MaxUint256);
  })

  it('should deposit 10000 LP tokens through AutoCompounder', async () => {
    const initialBalance = await autoCompounder.balanceOf(deployer.address);
    await autoCompounder.deposit(toWei("10000"), deployer.address);
    const balance = await autoCompounder.balanceOf(deployer.address);
    console.log(`Balance after first deposit: `, balance.toString());
    expect(balance).to.equal(initialBalance.add(toWei("10000")));
  });

  it('should deposit additional 10000 LP tokens through AutoCompounder', async () => {
    const initialBalance = await autoCompounder.balanceOf(deployer.address);
    await autoCompounder.deposit(toWei("10000"), deployer.address);
    const balance = await autoCompounder.balanceOf(deployer.address);
    console.log(`Balance after second deposit: `, balance.toString());
    expect(balance).to.equal(initialBalance.add(toWei("10000")));
  });

  it('should withdraw 10000 LP tokens through AutoCompounder', async () => {
    const [initialACBalance, initialBalance] = await Promise.all([
      autoCompounder.balanceOf(deployer.address),
      lpToken.balanceOf(deployer.address)
    ]);
    await autoCompounder.withdraw(deployer.address, toWei("10000"));
    const [acBalance, balance] = await Promise.all([
      autoCompounder.balanceOf(deployer.address),
      lpToken.balanceOf(deployer.address)
    ]);
    console.log('Intial balance', initialBalance.toString());
    console.log('balance', balance.toString());
    expect(acBalance).to.equal(initialACBalance.sub(toWei("10000")));
    expect(balance).to.equal(initialBalance.add(toWei("10000")));
  });

















  // let deployer: Wallet;

  // let loadFixture: ReturnType<typeof waffle.createFixtureLoader>;

  // let token0: IERC20;
  // let tokenA: IERC20;
  // let factoryV2: Contract;
  // let router: IUniswapV2Router02;
  // let pair: Contract;
  // let pool: IUniswapV3Pool;
  // let owner: SignerWithAddress;
  // let acc1: Wallet;
  // let acc2: Wallet;
  // let fee: Fee;
  // let quoter: MockUniswapV3Quoter;
  // let stakingReward: StakingRewards;
  // let autocompounderFactory: AutoCompounderFactory;
  // let autocompounder: AutoCompounder;
  // const deadline = 1726756514;

  // before("create fixture loader", async () => {
  //   wallets = await (ethers as any).getSigners();
  //   deployer = wallets[0];
  //   acc1 = wallets[1];
  //   acc2 = wallets[2];
  //   [owner] = await ethers.getSigners();

  //   // mock quoter
  //   const quoterDeployer = await ethers.getContractFactory("MockUniswapV3Quoter");
  //   quoter = (await quoterDeployer.deploy()) as MockUniswapV3Quoter;
  // });

  // beforeEach(async () => {
  //   loadFixture = waffle.createFixtureLoader(wallets as any);

  //   ({ token0, tokenA, factoryV2, router, pair } = await loadFixture(v2Fixture));

  //   const feeDeployer = await ethers.getContractFactory("MockFee");
  //   fee = (await feeDeployer.deploy()) as Fee;

  //   const stakingRewardDeployer = await ethers.getContractFactory("StakingRewards");
  //   stakingReward = (await stakingRewardDeployer.deploy(
  //     owner.address,
  //     acc1.address,
  //     tokenA.address,
  //     pair.address
  //   )) as StakingRewards;

  //   const autocompounderFactoryDeployer = await ethers.getContractFactory("AutoCompounderFactory");
  //   autocompounderFactory = (await autocompounderFactoryDeployer.deploy()) as AutoCompounderFactory;

  //   // set factory address
  //   await autocompounderFactory.setUniswapV2Factory(factoryV2.address);

  //   // create autocompounder for farm
  //   const autocompounderAddr = await autocompounderFactory.callStatic.createAutoCompounder(
  //     fee.address,
  //     stakingReward.address, // farming pool
  //     router.address, // router
  //     1, // single reward type
  //     tokenA.address, // UBE
  //     ethers.constants.AddressZero, // CELO
  //     ethers.constants.AddressZero,
  //     {
  //       gasLimit: 30000000,
  //     }
  //   );

  //   await autocompounderFactory.createAutoCompounder(
  //     fee.address,
  //     stakingReward.address, // farming pool
  //     router.address, // router
  //     1, // single reward type
  //     tokenA.address, // UBE
  //     ethers.constants.AddressZero, // CELO
  //     ethers.constants.AddressZero,
  //     {
  //       gasLimit: 30000000,
  //     }
  //   );

  //   autocompounder = (await ethers.getContractAt("AutoCompounder", autocompounderAddr)) as AutoCompounder;
  //   // transfer to fake reward
  //   await token0.transfer(stakingReward.address, toWei("10000000"));
  //   await tokenA.transfer(stakingReward.address, toWei("10000000"));

  //   // approve
  //   await token0.approve(autocompounder.address, ethers.constants.MaxUint256);
  //   await tokenA.approve(autocompounder.address, ethers.constants.MaxUint256);
  //   await pair.approve(autocompounder.address, ethers.constants.MaxUint256);

  //   // approve for router and pair
  //   await token0.approve(router.address, ethers.constants.MaxUint256);
  //   await tokenA.approve(router.address, ethers.constants.MaxUint256);
  //   await token0.approve(pair.address, ethers.constants.MaxUint256);
  //   await tokenA.approve(pair.address, ethers.constants.MaxUint256);

  //   // mint LP token
  //   await router
  //     .connect(deployer)
  //     .addLiquidity(
  //       tokenA.address,
  //       token0.address,
  //       toWei("1000"),
  //       toWei("5000"),
  //       toWei("100"),
  //       toWei("100"),
  //       deployer.address,
  //       deadline
  //     );
  // });

  // it("deposit, farm and withdraw", async () => {
  //   // get UBE token amount
  //   const beforeUBEAmount = await tokenA.callStatic.balanceOf(deployer.address);
  //   console.log("\x1b[36m%s\x1b[0m", "beforeUBEAmount", fromWei(beforeUBEAmount.toString()));

  //   await autocompounder.deposit(toWei("100"), deployer.address);
  //   await autocompounder.claimAndFarm();
  //   await autocompounder.claimAndFarm();
  //   // get LP token amount
  //   await autocompounder.withdraw(deployer.address, await autocompounder.balanceOf(deployer.address));

  //   // get UBE token amount
  //   const afterUBEAmount = await tokenA.callStatic.balanceOf(deployer.address);
  //   console.log("\x1b[36m%s\x1b[0m", "afterUBEAmount", fromWei(afterUBEAmount.toString()));
  // });

  // it("deposit", async () => {
  //   await expect(autocompounder.claim(deployer.address)).to.not.reverted;
  //   // get LP token amount
  //   const amountLP = await pair.callStatic.balanceOf(deployer.address);
  //   console.log("🚀 ~ file: autocompounder.spec.ts ~ line 135 ~ it ~ amountLP", fromWei(amountLP.toString()));
  //   // allowance
  //   const allowance = await pair.callStatic.allowance(deployer.address, autocompounder.address);
  //   console.log("🚀 ~ file: autocompounder.spec.ts ~ line 153 ~ it ~ allowance", fromWei(allowance.toString()));
  //   // deposit 100
  //   await autocompounder.deposit(toWei("100"), deployer.address);

  //   await autocompounder.deposit(toWei("1"), deployer.address);

  //   await autocompounder.claimAndFarm();
  //   await autocompounder.claimAndFarm();
  //   // get LP token amount
  //   const ALPAmount = await autocompounder.balanceOf(deployer.address);
  //   console.log("🚀 ~ file: autocompounder.spec.ts ~ line 154 ~ it ~ ALPAmount", fromWei(ALPAmount.toString()));

  //   await autocompounder.withdraw(deployer.address, ALPAmount);
  //   const amountLPAfter = await pair.callStatic.balanceOf(deployer.address);
  //   console.log("🚀 ~ file: autocompounder.spec.ts ~ line 168 ~ it ~ amountLPAfter", fromWei(amountLPAfter.toString()));
  // });

  // it("withdraw", async () => {
  //   // deposit 100
  //   await autocompounder.deposit(toWei("100"), deployer.address);

  //   await autocompounder.deposit(toWei("1"), deployer.address);

  //   await autocompounder.claimAndFarm();

  //   const amount = await stakingReward.balanceOf(autocompounder.address);
  //   console.log("\x1b[36m%s\x1b[0m", "amount", fromWei(amount.toString()));
  //   await autocompounder.withdraw(deployer.address, toWei("5"));

  //   // get LP token amount
  //   const ALPAmount = await autocompounder.balanceOf(deployer.address);
  //   console.log("🚀 ~ file: autocompounder.spec.ts ~ line 154 ~ it ~ ALPAmount", fromWei(ALPAmount.toString()));
  //   await autocompounder.withdraw(deployer.address, ALPAmount);
  // });

  // it("claim rewards", async () => {
  //   // deposit 100
  //   await autocompounder.deposit(toWei("100"), deployer.address);

  //   await autocompounder.deposit(toWei("1"), deployer.address);

  //   await autocompounder.claimAndFarm();
  //   const beforeAmount = await tokenA.balanceOf(deployer.address);
  //   await autocompounder.claim(deployer.address);
  //   const afterAmount = await tokenA.balanceOf(deployer.address);
  //   expect(Number(fromWei(afterAmount.toString()))).to.be.greaterThan(Number(fromWei(beforeAmount.toString())));
  // });

  // it("withdraw - revert with reason NEA and NP", async () => {
  //   // deposit 100
  //   await autocompounder.deposit(toWei("100"), deployer.address);

  //   await autocompounder.deposit(toWei("1"), deployer.address);

  //   const ALPAmount = await autocompounder.balanceOf(deployer.address);

  //   await expect(
  //     autocompounder.withdraw(deployer.address, ALPAmount.add(ethers.BigNumber.from("10")))
  //   ).to.be.revertedWith("AC: NEA");
  // });

  // it("setting stats", async () => {
  //   // deposit 100
  //   await autocompounder.deposit(toWei("100"), deployer.address);

  //   const ALPAmount = await autocompounder.balanceOf(deployer.address);

  //   await expect(
  //     autocompounder.withdraw(deployer.address, ALPAmount.add(ethers.BigNumber.from("10")))
  //   ).to.be.revertedWith("AC: NEA");

  //   await autocompounder.emergencyWithdraw(deployer.address, await autocompounder.firstRewardAddress());
  //   await autocompounder.setFeeAddress(fee.address);
  //   await autocompounder.setFirstRewardAddress(token0.address);
  //   await autocompounder.setSecondRewardAddress(token0.address);
  //   await autocompounder.setThirdRewardAddress(token0.address);
  //   await autocompounder.setFarmingPoolType(1);
  //   await autocompounder.setUniswapV2Router(router.address);
  //   await fee.collectFee(deployer.address, token0.address);

  //   expect(await autocompounder.feeContract()).to.be.equal(fee.address);
  //   expect(await autocompounder.firstRewardAddress()).to.be.equal(token0.address);
  //   expect(await autocompounder.secondRewardAddress()).to.be.equal(token0.address);
  //   expect(await autocompounder.thirdRewardAddress()).to.be.equal(token0.address);
  //   expect(await autocompounder.uniswapV2Router()).to.be.equal(router.address);
  //   expect(await autocompounder.farmingPoolType()).to.be.equal(1);
  // });

  // it("setting stats - not admin role", async () => {
  //   // deposit 100
  //   await autocompounder.deposit(toWei("100"), deployer.address);

  //   const ALPAmount = await autocompounder.balanceOf(deployer.address);

  //   await expect(
  //     autocompounder.withdraw(deployer.address, ALPAmount.add(ethers.BigNumber.from("10")))
  //   ).to.be.revertedWith("AC: NEA");

  //   await expect(
  //     autocompounder.connect(acc2).emergencyWithdraw(deployer.address, await autocompounder.firstRewardAddress())
  //   ).to.be.revertedWith("AC: ADR");
  //   await expect(autocompounder.connect(acc2).setFeeAddress(fee.address)).to.be.revertedWith("AC: ADR");
  //   await expect(autocompounder.connect(acc2).setFirstRewardAddress(fee.address)).to.be.revertedWith("AC: ADR");
  //   await expect(autocompounder.connect(acc2).setSecondRewardAddress(fee.address)).to.be.revertedWith("AC: ADR");
  //   await expect(autocompounder.connect(acc2).setThirdRewardAddress(fee.address)).to.be.revertedWith("AC: ADR");
  //   await expect(autocompounder.connect(acc2).setFarmingPoolType(1)).to.be.revertedWith("AC: ADR");
  //   await expect(autocompounder.connect(acc2).setUniswapV2Router(fee.address)).to.be.revertedWith("AC: ADR");

  //   await expect(fee.connect(acc2).collectFee(deployer.address, token0.address)).to.be.reverted;
  // });

  // it("deposit 0", async () => {
  //   await autocompounder.deposit(toWei("0"), deployer.address);
  // });

  // it("autocompounder name", async () => {
  //   const token0Name = await token0.symbol();
  //   const tokenAName = await tokenA.symbol();
  //   const expectedName = `${token0Name}-${tokenAName}-1 AutoCompounder LP Token`;
  //   const expectedSymbol = `${token0Name}-${tokenAName}-1 ALP`;

  //   expect(await autocompounder.name()).to.be.equal(expectedName);
  //   expect(await autocompounder.symbol()).to.be.equal(expectedSymbol);
  // });

  // it("should transfer fee to fee contract", async () => {
  //   const feeContractToken0BalanceBefore = await tokenA.balanceOf(fee.address);
  //   console.log(
  //     "\x1b[36m%s\x1b[0m",
  //     "feeContractToken0BalanceBefore",
  //     fromWei(feeContractToken0BalanceBefore.toString())
  //   );

  //   // deposit 100
  //   await autocompounder.deposit(toWei("100"), deployer.address);

  //   await autocompounder.deposit(toWei("1"), deployer.address);

  //   await autocompounder.claimAndFarm();
  //   const beforeAmount = await tokenA.balanceOf(deployer.address);
  //   await autocompounder.claim(deployer.address);
  //   const afterAmount = await tokenA.balanceOf(deployer.address);

  //   const feeContractToken0BalanceAfter = await tokenA.balanceOf(fee.address);
  //   console.log(
  //     "\x1b[36m%s\x1b[0m",
  //     "feeContractToken0BalanceAfter",
  //     fromWei(feeContractToken0BalanceAfter.toString())
  //   );
  //   await fee.collectFee(deployer.address, tokenA.address);
  //   expect(Number(fromWei(feeContractToken0BalanceAfter.toString()))).to.be.greaterThan(
  //     Number(fromWei(feeContractToken0BalanceBefore.toString()))
  //   );
  //   expect(Number(fromWei(afterAmount.toString()))).to.be.greaterThan(Number(fromWei(beforeAmount.toString())));
  // });

  // context("With ALP Token", () => {
  //   beforeEach(async () => {
  //     // deposit 100
  //     await autocompounder.deposit(toWei("100"), deployer.address);

  //     await autocompounder.deposit(toWei("1"), deployer.address);
  //   });

  //   it("should not withdraw", async () => {
  //     // get LP token amount
  //     const ALPAmount = await autocompounder.balanceOf(deployer.address);
  //     await expect(autocompounder.withdraw(deployer.address, ALPAmount.mul(2))).to.be.revertedWith("AC: NEA");
  //   });

  //   it("should transfer ALP", async () => {
  //     const acc1BeforeALP = await autocompounder.balanceOf(acc1.address);
  //     expect(acc1BeforeALP).to.be.equal(toWei("0"));

  //     const ALPAmount = await autocompounder.balanceOf(deployer.address);
  //     await autocompounder.transfer(acc1.address, ALPAmount.div(2));

  //     const acc1AfterALP = await autocompounder.balanceOf(acc1.address);
  //     expect(acc1AfterALP).to.be.equal(ALPAmount.div(2));
  //   });

  //   it("should transferFrom ALP", async () => {
  //     const acc1BeforeALP = await autocompounder.balanceOf(acc1.address);
  //     expect(acc1BeforeALP).to.be.equal(toWei("0"));

  //     const ALPAmount = await autocompounder.balanceOf(deployer.address);
  //     await autocompounder.approve(acc1.address, ALPAmount);
  //     const allowance = await autocompounder.allowance(deployer.address, acc1.address);
  //     expect(allowance).to.be.equal(ALPAmount);

  //     await autocompounder.connect(acc1).transferFrom(deployer.address, acc1.address, ALPAmount.div(2));

  //     const acc1AfterALP = await autocompounder.balanceOf(acc1.address);
  //     expect(acc1AfterALP).to.be.equal(ALPAmount.div(2));
  //   });

  //   it("should not mint to zero address", async () => {
  //     await expect(autocompounder.deposit(toWei("1"), ethers.constants.AddressZero)).to.be.revertedWith(
  //       "MINT_TO_THE_ZERO_ADDRESS"
  //     );

  //     const ALPAmount = await autocompounder.balanceOf(deployer.address);
  //     await expect(autocompounder.transfer(ethers.constants.AddressZero, ALPAmount.div(2))).to.be.revertedWith(
  //       "TRANSFER_TO_THE_ZERO_ADDRESS"
  //     );
  //   });

  //   it("should not transfer exceeds balance", async () => {
  //     await expect(autocompounder.deposit(toWei("1"), ethers.constants.AddressZero)).to.be.revertedWith(
  //       "MINT_TO_THE_ZERO_ADDRESS"
  //     );

  //     const ALPAmount = await autocompounder.balanceOf(deployer.address);
  //     await expect(autocompounder.transfer(acc1.address, ALPAmount.mul(2))).to.be.revertedWith(
  //       "TRANSFER_AMOUNT_EXCEEDS_BALANCE"
  //     );
  //   });
  // });
});
