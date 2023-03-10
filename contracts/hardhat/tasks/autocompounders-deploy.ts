import {IERC20__factory} from "./../../typechain/factories/IERC20__factory";
import {AutoCompounderFactory__factory} from "./../../typechain/factories/AutoCompounderFactory__factory";
import {AutoCompounder__factory} from "../../typechain";
import {task} from "hardhat/config";
import * as fs from 'fs';
import * as path from 'path';
import * as csv from 'fast-csv';
import { ethers } from "hardhat";
import { AutoCompounderFactory } from "../../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {SETTINGS} from '../../hardhat/common';
import axios from 'axios'
// task 1
task("init:autocompounders-factory").setAction(async (_, hre) => {
  const {deployments, ethers, getChainId} = hre;
  const [deployer] = await ethers.getSigners();
  const chainId : string = await getChainId();
  const AutoCompounderFactoryContract = await deployments.get("AutoCompounderFactory");
  console.log("\x1b[36m%s\x1b[0m", "chain.id", chainId);
  console.log("\x1b[36m%s\x1b[0m", "autocompounderFactory.address", AutoCompounderFactoryContract.address);
  console.log("\x1b[36m%s\x1b[0m", "autocompounderFactory.uniswapV2FactoryAddress", SETTINGS[parseInt(chainId)].uniswapV2FactoryAddress);

  const autoCompounderFactoryInstance = (
    await AutoCompounderFactory__factory.connect(AutoCompounderFactoryContract.address, ethers.provider)
  ).connect(deployer);
  const tx = await autoCompounderFactoryInstance.setUniswapV2Factory(SETTINGS[parseInt(chainId)].uniswapV2FactoryAddress, {
    gasLimit: 2000000,
  });

  console.log("\x1b[36m%s\x1b[0m", "tx", tx);
});

// task 2
task("create:autocompounders-from-file")
  .addOptionalParam("appApiUrl")
  .addOptionalParam("inputFile")
  .addOptionalParam("farmId")
  .setAction(async (taskArgs, hre) => {
    const {deployments, ethers, getChainId} = hre;
    const [deployer] = await ethers.getSigners();

    const {appApiUrl, inputFile, farmId} = taskArgs;
    const AutocompounderFactoryContract = await deployments.get("AutoCompounderFactory");
    const feeAddress = (await deployments.get("Fee")).address;
    const chainId : string = await getChainId();
    console.log("\x1b[36m%s\x1b[0m", "chain.id", chainId);
    const autoCompounderFactoryInstance = await AutoCompounderFactory__factory.connect(
      AutocompounderFactoryContract.address,
      ethers.provider
    );
    //read input file
      const input = await getAutocompundersInput(inputFile);
      for(const ac of input){
        try{
          console.log("\x1b[36m%s\x1b[0m", "Deploying autocompounder for farm", ac.farmName);
          console.log("\x1b[36m%s\x1b[0m", "AutocompounderFactoryContract", autoCompounderFactoryInstance.address);
          console.log("\x1b[36m%s\x1b[0m", "farmingPoolAddress", ac.stakingAddress);
          console.log("\x1b[36m%s\x1b[0m", "feeAddress", feeAddress);
          console.log("\x1b[36m%s\x1b[0m", "token1", ac.rewardToken);
          console.log("\x1b[36m%s\x1b[0m", "token2", ac.externalRewardToken1 || ethers.constants.AddressZero);
          console.log("\x1b[36m%s\x1b[0m", "token3", ac.externalRewardToken2 || ethers.constants.AddressZero);
          console.log("\x1b[36m%s\x1b[0m", "uniswapRouterAddress", SETTINGS[parseInt(chainId)].uniswapRouterAddress);


          let tx: any = await autoCompounderFactoryInstance.connect(deployer).createAutoCompounder(
            feeAddress,
            ac.stakingAddress, // farming pool
            SETTINGS[parseInt(chainId)].uniswapRouterAddress, // router
            parseInt(ac.rewardTokens), // number of reward tokens (1,2,3)
            ac.rewardToken, // UBE
            ac.externalRewardToken1  || ethers.constants.AddressZero,
            ac.externalRewardToken2  || ethers.constants.AddressZero
          );
          console.log("\x1b[36m%s\x1b[0m", "tx", tx);
          tx = await tx.wait();

          const autoCompounderAddress = tx.events[tx.events.length - 1].args.autoCompounder;
          console.log("\x1b[36m%s\x1b[0m", "autoCompounder.deployment", `Autocompounder ${autoCompounderAddress} deployed`);
          if(appApiUrl){
            const dbAutocompounder = await axios.post(`${appApiUrl}/farms/${farmId}/autocompounders`, 
                {
                  address: autoCompounderAddress,
                  name: ac.farmName,
                  active: true,
                  stakingReward: ac.stakingAddress,
                  stakingToken: ac.stakingToken,
                  rewardsToken: ac.rewardToken,
                  token0Name: ac.token0Name,
                  token1Name: ac.token1Name
                });
            console.log("\x1b[36m%s\x1b[0m", "autoCompounder.database", `Autocompounder ${autoCompounderAddress} added  to database`);
          }

        } catch(ex){
          console.error("Unable to deploy autocompounder for farm "+ac.farmName + "/n"+ex);
        }
      }
  });

// update rewards
/*task("update:autocompounders-from-file")
  .addOptionalParam("appApiUrl")
  .addOptionalParam("inputFile")
  .addOptionalParam("farmId")
  .setAction(async (taskArgs, hre) => {
    const {ethers} = hre;
    const [deployer] = await ethers.getSigners();

    const {appApiUrl, inputFile, farmId} = taskArgs;
    const input = await getAutocompundersInput(inputFile);
    for (const ac of input){
      try {
        console.log("\x1b[36m%s\x1b[0m", `Updating rewards for autocompounder ${ac.farmName}`);

        const result = await axios.get(`${appApiUrl}/farms/${farmId}/autocompounders/search/${ac.farmName}`);
        let autocompounder = result.data.data;
        const autoCompounderInstance = await AutoCompounder__factory.connect(
          autocompounder.address,
          ethers.provider
        );

        let tx: any = await autoCompounderInstance.connect(deployer).setFirstRewardAddress(ac.rewardToken);
        console.log("\x1b[36m%s\x1b[0m", "tx", tx);
        tx = await tx.wait();
        console.log("\x1b[36m%s\x1b[0m", `Autocompounder ${ac.farmName} updated in contract`);

        const autocompounderId = autocompounder.id;
        delete autocompounder.id;
        autocompounder.rewardsToken = ac.rewardToken;
        ac.externalRewardToken1 ? autocompounder.externalRewardToken1 = ac.externalRewardToken1 : autocompounder.externalRewardToken1 = null;
        ac.externalRewardToken2 ? autocompounder.externalRewardToken2 = ac.externalRewardToken2 : autocompounder.externalRewardToken2 = null;

        await axios.put(`${appApiUrl}/farms/${farmId}/autocompounders/${autocompounderId}`, autocompounder);
        console.log("\x1b[36m%s\x1b[0m",`Autocompounder ${ac.farmName} updated in database`);
      } 
      catch(ex){
        console.error("Unable to update rewards for autocompounder " + ac.farmName + "/n" + ex);
      }
    }
  });*/

task("create:new-ac")
  .addOptionalParam("inputFile")
  .setAction(async (taskArgs, hre) => {
    const {deployments, ethers, getChainId} = hre;
    const [deployer] = await ethers.getSigners();

    const {inputFile} = taskArgs;
    const AutocompounderFactoryContract = await deployments.get("AutoCompounderFactory");
    const feeAddress = (await deployments.get("Fee")).address;
    const chainId : string = await getChainId();
    console.log("\x1b[36m%s\x1b[0m", "chain.id", chainId);
    const autoCompounderFactoryInstance = await AutoCompounderFactory__factory.connect(
      AutocompounderFactoryContract.address,
      ethers.provider
    );
    //read input file
      const input = await getAutocompundersInput(inputFile);
      for(const ac of input){

        try{
          console.log("\x1b[36m%s\x1b[0m", "Deploying autocompounder for farm", ac.farmName);
          console.log("\x1b[36m%s\x1b[0m", "AutocompounderFactoryContract", autoCompounderFactoryInstance.address);
          console.log("\x1b[36m%s\x1b[0m", "farmingPoolAddress", ac.stakingAddress);
          console.log("\x1b[36m%s\x1b[0m", "feeAddress", feeAddress);
          console.log("\x1b[36m%s\x1b[0m", "token1", ac.rewardToken);
          console.log("\x1b[36m%s\x1b[0m", "token2", ac.externalRewardToken1 || ethers.constants.AddressZero);
          console.log("\x1b[36m%s\x1b[0m", "token3", ac.externalRewardToken2 || ethers.constants.AddressZero);
          console.log("\x1b[36m%s\x1b[0m", "uniswapRouterAddress", SETTINGS[parseInt(chainId)].uniswapRouterAddress);

          let tx: any = await autoCompounderFactoryInstance.connect(deployer).createAutoCompounder(
            feeAddress,
            ac.stakingAddress, // farming pool
            SETTINGS[parseInt(chainId)].uniswapRouterAddress, // router
            parseInt(ac.rewardTokens), // number of reward tokens (1,2,3)
            ac.rewardToken, // UBE
            ac.externalRewardToken1  || ethers.constants.AddressZero,
            ac.externalRewardToken2  || ethers.constants.AddressZero,
          );

          console.log("\x1b[36m%s\x1b[0m", "tx", tx);
          tx = await tx.wait();

          const autoCompounderAddress = tx.events[tx.events.length - 1].args.autoCompounder;
          console.log("\x1b[36m%s\x1b[0m", "autoCompounder.deployment", `Autocompounder ${autoCompounderAddress} deployed`);
          
        } catch(ex){
          console.error("Unable to deploy autocompounder for farm "+ac.farmName + "/n"+ex);
        }
      }
  });

const getAutocompundersInput = async(inputFile: string) : Promise<any[]> => {
    let result: any[] =  [];
    return new Promise((resolve: any, reject: any) => {
      fs.createReadStream(path.resolve(__dirname, 'input-files', inputFile))
      .pipe(csv.parse({ headers: true, delimiter: ',' }))
      .on('error', error => reject(error))
      .on('data', (row) => {result.push(row)})
      .on('end', (rowCount: number) => resolve(result));
    })
};


