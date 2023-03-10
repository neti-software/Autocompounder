// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface IAutoCompounderDeployer {
    function parameters()
        external
        returns (
            address feeContract,
            address factory,
            address farmingPoolAddress,
            address uniswapV2Router,
            uint8 farmingPoolType,
            address firstRewardAddress,
            address secondRewardAddress,
            address thirdRewardAddress
        );
}
