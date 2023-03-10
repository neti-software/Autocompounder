import {ethers, waffle} from "hardhat";
import {Fixture} from "ethereum-waffle";
import {utils, Contract, constants, Signer} from "ethers";

import {abi, bytecode} from "../../artifacts/contracts/mocks/StakingRewards.sol/StakingRewards2.json";

import {StakingRewards} from "../../typechain";

export const stakingRewardFixture: Fixture<StakingRewards> = async ([wallet]) => {
  return (await waffle.deployContract(
    wallet as unknown as Signer,
    {
      bytecode: bytecode,
      abi: abi,
    },
    [wallet.address, wallet.address]
  )) as StakingRewards;
};
