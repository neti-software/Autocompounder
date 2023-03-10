import {DeployFunction} from "hardhat-deploy/dist/types";
import {HardhatRuntimeEnvironment} from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const MultiSignContract = await deployments.get("MultiSignatureContract");

  const factory = await deploy("AutoCompounderFactory", {
    from: deployer,
    args: ["0x0d70296730060519B6d76F32e461FF7f80E54318"], // should be multisig address, for test hardcoded address
  });

  console.log("\x1b[36m%s\x1b[0m", "factory.address", factory.address);
};

func.tags = ["AutoCompounderFactory"];
export default func;
