// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

interface IAutoCompounderFactory {
    event AutoCompounderCreated(address indexed autoCompounder);

    function uniswapV2Factory() external view returns (IUniswapV2Factory);

    function createAutoCompounder(
        address _feeContract,
        address _farmingPoolAddress,
        address _uniswapV2Router,
        uint8 _farmingPoolType,
        address _firstRewardAddress,
        address _secondRewardAddress,
        address _thirdRewardAddress
    ) external returns (address autoCompounder);
}
