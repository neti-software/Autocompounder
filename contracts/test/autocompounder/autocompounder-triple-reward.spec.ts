import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {expect} from "chai";
import {Contract, Wallet} from "ethers";
import {ethers, waffle} from "hardhat";
import web3 from "web3";
import {
  AutoCompounder,
  AutoCompounderFactory,
  Fee,
  MockUniswapV3Quoter,
  MoolaStakingRewards,
  StakingRewards,
} from "../../typechain";
import {AutoCompounder__factory} from "../../typechain/factories/AutoCompounder__factory";
import {IERC20} from "../../typechain/IERC20";
import {IUniswapV2Router02} from "../../typechain/IUniswapV2Router02";
import {IUniswapV3Pool} from "../../typechain/IUniswapV3Pool";
import {v2Fixture} from "../utils/fixtureUniswapV2";

const {toWei, fromWei} = web3.utils;

describe("AutoCompounder", () => {
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
  let fee: Fee;
  let quoter: MockUniswapV3Quoter;
  let stakingReward: StakingRewards;
  let stakingMultiRewards: MoolaStakingRewards;
  let autocompounderFactory: AutoCompounderFactory;
  let autocompounder: AutoCompounder;
  const deadline = 1726756514;

  before("create fixture loader", async () => {
    wallets = await (ethers as any).getSigners();
    deployer = wallets[0];
    acc1 = wallets[1];
    acc2 = wallets[2];
    [owner] = await ethers.getSigners();

    // mock quoter
    const quoterDeployer = await ethers.getContractFactory("MockUniswapV3Quoter");
    quoter = (await quoterDeployer.deploy()) as MockUniswapV3Quoter;
  });

  beforeEach(async () => {
    loadFixture = waffle.createFixtureLoader(wallets as any);

    ({token0, token1, factoryV2, router, pair} = await loadFixture(v2Fixture));

    const feeDeployer = await ethers.getContractFactory("Fee");
    fee = (await feeDeployer.deploy()) as Fee;

    const stakingRewardDeployer = await ethers.getContractFactory("StakingRewards");
    stakingReward = (await stakingRewardDeployer.deploy(
      owner.address,
      acc1.address,
      token1.address,
      pair.address
    )) as StakingRewards;

    const stakingMultiRewardsDeployer = await ethers.getContractFactory("MoolaStakingRewards");
    stakingMultiRewards = (await stakingMultiRewardsDeployer.deploy(
      owner.address,
      acc1.address,
      token1.address, // reward token
      stakingReward.address, // external staking rewards
      [token0.address, token1.address] // external reward tokens
    )) as MoolaStakingRewards;

    const autocompounderFactoryDeployer = await ethers.getContractFactory("AutoCompounderFactory");
    autocompounderFactory = (await autocompounderFactoryDeployer.deploy()) as AutoCompounderFactory;

    // set factory address
    await autocompounderFactory.setUniswapV2Factory(factoryV2.address);

    // create autocompounder for farm
    const autocompounderAddr = await autocompounderFactory.callStatic.createAutoCompounder(
      fee.address,
      stakingMultiRewards.address, // farming pool
      router.address, // router
      3, // triple reward type
      token1.address, // UBE
      token0.address, // CELO
      token0.address,
      {
        gasLimit: 30000000,
      }
    );

    autocompounderFactory.createAutoCompounder(
      fee.address,
      stakingMultiRewards.address, // farming pool
      router.address, // router
      3, // triple reward type
      token1.address, // UBE
      token0.address, // CELO
      token0.address,
      {
        gasLimit: 30000000,
      }
    );

    autocompounder = AutoCompounder__factory.connect(autocompounderAddr, deployer);

    // transfer to fake reward
    await token0.transfer(stakingReward.address, toWei("10000000"));
    await token1.transfer(stakingReward.address, toWei("10000000"));

    await token0.transfer(stakingMultiRewards.address, toWei("10000000"));
    await token1.transfer(stakingMultiRewards.address, toWei("10000000"));

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
  });

  it("deposit", async () => {
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    await autocompounder.deposit(toWei("1"), deployer.address);

    // get LP token amount
    const ALPAmount = await autocompounder.balanceOf(deployer.address);
    console.log("🚀 ~ file: autocompounder.spec.ts ~ line 154 ~ it ~ ALPAmount", fromWei(ALPAmount.toString()));
    await autocompounder.claimAndFarm();
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

  it("withdraw - revert with reason NEA and NP", async () => {
    // deposit 100
    await autocompounder.deposit(toWei("100"), deployer.address);

    await autocompounder.deposit(toWei("1"), deployer.address);

    const ALPAmount = await autocompounder.balanceOf(deployer.address);

    await expect(
      autocompounder.withdraw(deployer.address, ALPAmount.add(ethers.BigNumber.from("10")))
    ).to.be.revertedWith("AC: NEA");
    await expect(autocompounder.withdraw(deployer.address, ethers.BigNumber.from("0"))).to.be.revertedWith("AC: NP");
  });

  it("deposit 0", async () => {
    await autocompounder.deposit(toWei("0"), deployer.address);
  });
});
