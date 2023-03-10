import {DeployFunction} from "hardhat-deploy/dist/types";
import {HardhatRuntimeEnvironment} from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const fee = await deploy("Fee", {
    from: deployer,
    args: [],
  });

  console.log("\x1b[36m%s\x1b[0m", "fee.address", fee.address);
};

func.tags = ["Fee"];
export default func;
