import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {expect} from "chai";
import {Contract, Wallet} from "ethers";
import {ethers, waffle} from "hardhat";
import web3 from "web3";
import {AutoCompounder, AutoCompounderFactory, MockUniswapV3Quoter} from "../../typechain";
import {IERC20} from "../../typechain/IERC20";
import {IUniswapV2Router02} from "../../typechain/IUniswapV2Router02";
import {IUniswapV3Pool} from "../../typechain/IUniswapV3Pool";
import {ADMIN_ROLE} from "../utils/constant";
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
  let quoter: MockUniswapV3Quoter;
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

    const autocompounderFactoryDeployer = await ethers.getContractFactory("AutoCompounderFactory");
    autocompounderFactory = (await autocompounderFactoryDeployer.deploy()) as AutoCompounderFactory;

    // set factory address
    await autocompounderFactory.setUniswapV2Factory(factoryV2.address);
  });

  it("add new REBALANCE_ROLE", async () => {
    const [, newOwner, notOwner] = await ethers.getSigners();
    const tryChange = autocompounderFactory.connect(notOwner).grantRole(ADMIN_ROLE, await notOwner.getAddress());
    expect(tryChange).to.be.reverted;

    await autocompounderFactory.grantRole(ADMIN_ROLE, await newOwner.getAddress());
    expect(await autocompounderFactory.hasRole(ADMIN_ROLE, await newOwner.getAddress())).to.be.equal(true);
  });

  it("set UniswapV2Factory", async () => {
    await autocompounderFactory.setUniswapV2Factory(ethers.constants.AddressZero);
    const uniFactoryAddress = await autocompounderFactory.uniswapV2Factory();

    expect(uniFactoryAddress).to.equal(ethers.constants.AddressZero);
  });

  it("modifier onlyOwner", async () => {
    const [, user] = await ethers.getSigners();
    expect(autocompounderFactory.setUniswapV2Factory(ethers.constants.AddressZero)).to.be.not.reverted;
    expect(autocompounderFactory.connect(user).setUniswapV2Factory(ethers.constants.AddressZero)).to.be.reverted;
  });

  it("create autocompounder - revert with reason AC: AR", async () => {
    const [, user] = await ethers.getSigners();
    const feeDeployer = await ethers.getContractFactory("Fee");
    const fee = await feeDeployer.deploy();
    expect(
      autocompounderFactory.connect(user).createAutoCompounder(
        fee.address,
        token0.address, // farming pool
        router.address, // router
        2, // triple reward type
        token1.address, // UBE
        token0.address, // CELO
        ethers.constants.AddressZero,
        {
          gasLimit: 30000000,
        }
      )
    ).to.be.revertedWith("AC: AR");
  });
});
