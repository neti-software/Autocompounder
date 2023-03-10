#!/bin/sh

yarn hardhat create:autocompounder --network celo --farming-pool-address 0xb450940c5297e9b5e7167FAC5903fD1e90b439b8 --type 3 --token1 0x00Be915B9dCf56a3CBE739D9B9c202ca692409EC --token2 0x471EcE3750Da237f93B8E339c536989b8978a438 --token3 0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B
yarn hardhat create:autocompounder --network celo --farming-pool-address 0x9D87c01672A7D02b2Dc0D0eB7A145C7e13793c3B --type 2 --token1 0x00Be915B9dCf56a3CBE739D9B9c202ca692409EC --token2 0x471EcE3750Da237f93B8E339c536989b8978a438
yarn hardhat create:autocompounder --network celo --farming-pool-address 0x19F1A692C77B481C23e9916E3E83Af919eD49765 --type 1 --token1 0x00Be915B9dCf56a3CBE739D9B9c202ca692409EC
