import {Fixture} from "ethereum-waffle";
import {Signer} from "ethers";
import {waffle} from "hardhat";
import {
  abi as RB_FACTORY_ABI,
  bytecode as RB_FACTORY_BYTECODE,
} from "../../artifacts/contracts/auto-compounder/AutoCompounderFactory.sol/AutoCompounderFactory.json";
import {IAutoCompounderFactory} from "../../typechain/IAutoCompounderFactory";

export const rebalanceFactoryFixture: Fixture<IAutoCompounderFactory> = async ([wallet]) => {
  return (await waffle.deployContract(wallet as unknown as Signer, {
    bytecode: RB_FACTORY_BYTECODE,
    abi: RB_FACTORY_ABI,
  })) as IAutoCompounderFactory;
};
