## Contracts

### Platform / language

- [Solidity](https://docs.soliditylang.org/en/v0.8.0/) - v0.8.0
- [Solidity](https://docs.soliditylang.org/en/v0.8.1/) - v0.8.1, 
- [Solidity](https://docs.soliditylang.org/en/v0.8.2/) - v0.8.2, 
- [Solidity](https://docs.soliditylang.org/en/v0.8.4/) - v0.8.4,
- [Hardhat](https://hardhat.org/) - v2.8.0 - deployment tehnology

### How to run tests

```
cd contracts
npm run test
```

### Deployment
#### Migrations (celo network)
```
  yarn hardhat compile
  yarn hardhat deploy --network celo --reset
  yarn hardhat init:autocompounder-factory --network celo
```

#### Deploy autocompounder
```
  yarn hardhat create:autocompounder --network celo --farming-pool-address 'farmin_pool_address_here' --type 'farm_type_here (1, 2, 3 - depending on rewards tokens)' --token1 'reward1_address_here' --token2 'reward2_address_here' --token3 'reward3_address_here'
```

