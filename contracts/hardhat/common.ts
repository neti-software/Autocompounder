import { constants } from "ethers";

export const CHAIN_IDS = {
  hardhat: 1337,
  kovan: 42,
  rinkeby: 4,
  celo: 42220,
  alfajores: 44787,
  avalanche: 43114,
  fuji: 43113

};

export const SETTINGS: {
  [chainId: number] : {signers: string[], minSignatures: number, uniswapRouterAddress: string, uniswapV2FactoryAddress: string};}= {
    [CHAIN_IDS.alfajores] :{
      signers: ['0x941626568F36Afb029A5bAf1c13AED20aFa013a4'],
      minSignatures: 1,
      uniswapRouterAddress: '0xe58cBdFeBb2A37043fD81b958824b9BD99C69e9b',
      uniswapV2FactoryAddress: '0xB54C17223F07d954cF54847C71dCC6c93967Ea63'
    },
    [CHAIN_IDS.celo] :{
      signers: ['0x0d70296730060519B6d76F32e461FF7f80E54318'],
      minSignatures: 1,
      uniswapRouterAddress: '0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121',
      uniswapV2FactoryAddress: '0x62d5b84be28a183abb507e125b384122d2c25fae'
    },
    [CHAIN_IDS.avalanche] :{
      signers: ['0x0d70296730060519B6d76F32e461FF7f80E54318'],
      minSignatures: 1,
      uniswapRouterAddress: '0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106',
      uniswapV2FactoryAddress: '0xefa94DE7a4656D787667C749f7E1223D71E9FD88'
    },
    [CHAIN_IDS.fuji] :{
      signers: ['0x0d70296730060519B6d76F32e461FF7f80E54318'],
      minSignatures: 1,
      uniswapRouterAddress: '0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106',
      uniswapV2FactoryAddress: '0xefa94DE7a4656D787667C749f7E1223D71E9FD88'
    }
}

export const ADDRESSES_FOR_NETWORK: {
  [key: string]: { uniswapRouter02: string; weth: string; wbtc?: string; eth2usd?: string[]; nft: string };
} = {
  [CHAIN_IDS.hardhat]: {
    uniswapRouter02: constants.AddressZero,
    weth: constants.AddressZero,
    nft: constants.AddressZero,
  },
  [CHAIN_IDS.rinkeby]: {
    uniswapRouter02: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    weth: "0xc778417e063141139fce010982780140aa0cd5ab",
    nft: "0xc36442b4a4522e871399cd717abdd847ab11fe88",
    wbtc: "0x577d296678535e4903d59a4c929b718e1d575e0a",
    eth2usd: ["0xc778417e063141139fce010982780140aa0cd5ab", "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e"],
  },
};
