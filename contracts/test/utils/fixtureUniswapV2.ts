import {deployContract, Fixture} from "ethereum-waffle";
import {Contract} from "ethers";
import web3 from "web3";
import {abi as weth9abi, bytecode as weth9bytecode} from "../../artifacts/contracts/mocks/MockWETH.sol/MockWETH.json";
import {
  abi as univ2FactoryAbi,
  bytecode as univ2FactoryBytecode,
} from "@uniswap/v2-periphery/build/UniswapV2Router02.json";
import IUniswapV2Pair from "@uniswap/v2-core/build/IUniswapV2Pair.json";
import UniswapV2Factory from "@uniswap/v2-core/build/UniswapV2Factory.json";
import ERC20 from "@uniswap/v2-core/build/ERC20.json";
import {MockWETH} from "../../typechain";
import {IUniswapV2Router02} from "../../typechain/IUniswapV2Router02";
import {IERC20} from "../../typechain/IERC20";

interface V2Fixture {
  token0: IERC20;
  token1: IERC20;
  WETH: MockWETH;
  WETHPartner: Contract;
  factoryV2: Contract;
  router02: IUniswapV2Router02;
  router: IUniswapV2Router02;
  pair: Contract;
  WETHPair: Contract;
}

const overrides = {
  gasLimit: 9999999,
};
const {toWei} = web3.utils;

export const v2Fixture: Fixture<V2Fixture | any> = async ([wallet], provider) => {
  // deploy tokens
  const tokenA = (await deployContract(wallet as any, ERC20, [toWei("100000000")])) as unknown as IERC20;

  const tokenB = (await deployContract(wallet as any, ERC20, [toWei("100000000")])) as unknown as IERC20;
  const WETH = (await deployContract(wallet as any, {
    abi: weth9abi,
    bytecode: weth9bytecode,
  })) as unknown as MockWETH;
  const WETHPartner = await deployContract(wallet as any, ERC20, [toWei("10000")]);

  // deploy V2
  const factoryV2 = await deployContract(wallet as any, UniswapV2Factory, [wallet.address]);

  const router02 = (await deployContract(
    wallet as any,
    {
      abi: univ2FactoryAbi,
      bytecode: univ2FactoryBytecode,
    },
    [factoryV2.address, WETH.address],
    overrides
  )) as unknown as IUniswapV2Router02;

  // initialize V2
  await factoryV2.createPair(tokenA.address, tokenB.address);
  const pairAddress = await factoryV2.getPair(tokenA.address, tokenB.address);
  const pair = new Contract(pairAddress, JSON.stringify(IUniswapV2Pair.abi), provider as any).connect(wallet as any);

  const token0Address = await pair.token0();
  const token0 = tokenA.address === token0Address ? tokenA : tokenB;
  const token1 = tokenA.address === token0Address ? tokenB : tokenA;

  await factoryV2.createPair(WETH.address, WETHPartner.address);
  const WETHPairAddress = await factoryV2.getPair(WETH.address, WETHPartner.address);
  const WETHPair = new Contract(WETHPairAddress, JSON.stringify(IUniswapV2Pair.abi), provider as any).connect(
    wallet as any
  );

  return {
    token0,
    token1,
    WETH,
    WETHPartner,
    factoryV2,
    router02,
    router: router02, // the default router, 01 had a minor bug
    pair,
    WETHPair,
  };
};
