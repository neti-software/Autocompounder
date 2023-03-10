# AutoCompounder

## List reward tokens:
+ UBE: 0x62d5b84be28a183abac07e125b384122d2c25fae
+ CELO: 0x471EcE3750Da237f93B8E339c536989b8978a438
+ MOBI: 0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B
+ MOO: 0x17700282592D6917F6A73D0bF8AcCf4D578c131e

## Step to step deploy SC - factory:

+ Step 1: `yarn install` and create new .env file from .env.example
+ Step 2: run `yarn hardhat deploy --network celo --reset` to deploy autocompounder-factory contract
+ Step 3: `yarn hardhat init:autocompounder-factory --network celo` to set property ubeswapRouter in autocompounder-factory contract


## Guide create new autocompounder contract:
### Note
+ One farming pool in ubeswap has only one autocompounder contract

### Create new autocompounder
To create new autocompounder, you need to know:
+ farming pool address: to get it, go to ubeswap farm => click to farm you want => look at address bar, the farm address is the last address
+ token reward
+ after know two above params, let run the following command for triple rewards
```
yarn hardhat create:autocompounder --network celo --farming-pool-address <FARMING_POOL_ADDR> --type 3 --token1 <TOKEN_REWARD_1> --token2 <TOKEN_REWARD_2> --token3 <TOKEN_REWARD_3>
```

or with double rewards, run
```
yarn hardhat create:autocompounder --network celo --farming-pool-address <FARMING_POOL_ADDR> --type 2 --token1 <TOKEN_REWARD_1> --token2 <TOKEN_REWARD_2>
```

or with single reward, run
```
yarn hardhat create:autocompounder --network celo --farming-pool-address <FARMING_POOL_ADDR> --type 1 --token1 <TOKEN_REWARD_1>
```

example: 
```
yarn hardhat create:autocompounder --network celo --farming-pool-address 0x62d5b84be28a183abb507e125b384122d2c25fae --token1 0x62d5b84be28a183abac07e125b384122d2c25fae
```