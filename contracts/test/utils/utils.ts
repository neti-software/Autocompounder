import {BigNumber, ethers, Contract} from "ethers";
import {IUniswapV3Pool} from "../../typechain/IUniswapV3Pool";
import {AutoCompounder} from "../../typechain";
import {Currency, CurrencyAmount, Token} from "@uniswap/sdk-core";
import {FeeAmount, Pool, Position, TickMath} from "@uniswap/v3-sdk";
import {parseUnits} from "ethers/lib/utils";
const JSBI = require("jsbi");

export const getMinTick = (tickSpacing: number) => Math.ceil(-887272 / tickSpacing) * tickSpacing;
export const getMaxTick = (tickSpacing: number) => Math.floor(887272 / tickSpacing) * tickSpacing;
export const getMaxLiquidityPerTick = (tickSpacing: number) =>
  BigNumber.from(2)
    .pow(128)
    .sub(1)
    .div((getMaxTick(tickSpacing) - getMinTick(tickSpacing)) / tickSpacing + 1);

export const calcTickRanges = (): [BigNumber, BigNumber] => {
  return [BigNumber.from(3), BigNumber.from(3)];
};

export const convertToNumber = (value: BigNumber) => {
  return Number(ethers.utils.formatEther(value));
};

export const getCurrentTick = async (pool: IUniswapV3Pool | Contract) => {
  const slot0 = await pool.slot0();
  return slot0.tick;
};

export const calcTokenShares = async (
  pool: IUniswapV3Pool | Contract,
  upperValue: number,
  lowerValue: number
): Promise<[number, number, number, number]> => {
  const address0 = await pool.token0();
  const address1 = await pool.token1();
  const token0 = new Token(
    Number(process.env.CHAIN_ID || 4),
    address0,
    18, //decimal
    "TK0",
    "Token0"
  );

  const token1 = new Token(
    Number(process.env.CHAIN_ID || 4),
    address1,
    18, //decimal
    "TK1",
    "Token1"
  );

  // get current tick
  const slot0 = await pool.slot0();
  const currentTick = slot0.tick;
  const fee = await pool.fee();
  const liquidity = await pool.liquidity();
  const tickSpacing = await pool.tickSpacing();

  // cal tickLower vs tickUpper => amount of two token
  const tickLower = Math.ceil(currentTick / tickSpacing) * tickSpacing - lowerValue * tickSpacing;
  const tickUpper = Math.floor(currentTick / tickSpacing) * tickSpacing + upperValue * tickSpacing;
  console.log("\x1b[36m%s\x1b[0m", "{tickLower, tickUpper, currentTick, tickSpacing}", {
    tickLower,
    tickUpper,
    currentTick: slot0.tick,
    tickSpacing,
  });
  const token0Amount: CurrencyAmount<Currency> = tryParseAmount("20", token0);

  const poolSdk = new Pool(
    token0,
    token1,
    fee as FeeAmount,
    slot0.sqrtPriceX96.toString(),
    liquidity.toString(),
    slot0.tick
  );
  const position: Position | undefined = Position.fromAmount0({
    pool: poolSdk,
    tickLower: tickLower,
    tickUpper: tickUpper,
    amount0: token0Amount.quotient,
    useFullPrecision: true,
  });

  const amount0 = Number(position.amount0.toSignificant(6));
  const amount1 = Number(position.amount1.toSignificant(6));
  const token0Share = Math.floor((amount0 * 100) / (amount0 + amount1));
  const token1Share = 100 - token0Share;

  return [tickLower, tickUpper, token0Share, token1Share];
};

export function tryParseAmount<T extends Currency>(value: string, currency: T): CurrencyAmount<T> {
  const typedValueParsed = parseUnits(value, currency.decimals).toString();
  return CurrencyAmount.fromRawAmount(currency, JSBI.BigInt(typedValueParsed));
}

export const sleep = async (milisec: number): Promise<void> => {
  return new Promise((resolve) => setTimeout(resolve, milisec));
};
