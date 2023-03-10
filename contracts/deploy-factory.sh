#!/bin/sh

yarn hardhat compile
yarn hardhat deploy --network celo --reset
yarn hardhat init:autocompounders-factory --network celo
