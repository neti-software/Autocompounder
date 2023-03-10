import {DeployFunction} from "hardhat-deploy/dist/types";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import {SETTINGS} from '../../hardhat/common';
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const {deployments, getNamedAccounts, getChainId} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId : string = await getChainId();
  console.log("\x1b[36m%s\x1b[0m", "chain.id", chainId);

  const multisign = await deploy("MultiSignatureContract", {
    from: deployer,
    args: [SETTINGS[parseInt(chainId)].signers, SETTINGS[parseInt(chainId)].minSignatures],
  });

  console.log("\x1b[36m%s\x1b[0m", "multisign.address", multisign.address);
};

func.tags = ["MultiSignatureContract"];
export default func;
