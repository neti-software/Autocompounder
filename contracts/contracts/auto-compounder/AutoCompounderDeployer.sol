// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AutoCompounder.sol";
import "./interfaces/IAutoCompounderDeployer.sol";

///@title Autocompounder deployer contract
///@author NETI
///@dev Utility contract used in AutoCompounders deployment responsible for transferring initial parameters to minted AutoCompounder
contract AutoCompounderDeployer is IAutoCompounderDeployer {
    struct Parameters {
        address feeContract; // contract which compute fee
        address factory; // autocompounder factory
        address farmingPoolAddress; // farming pool addres
        address uniswapV2Router; // uniswap v2 router
        uint8 farmingPoolType; // farming pool type (single-1, double-2, triple-3)
        address firstRewardAddress; // first reward token
        address secondRewardAddress; // second reward token
        address thirdRewardAddress; // third reward token
    }

    // params pass to constructor in autocompounder => for verify contract more easy
    Parameters public override parameters;

    /// @dev create new autocompounder instance
    /// @param _feeContract Fee contract address
    /// @param _factory Autocompounder factory address
    /// @param _farmingPoolAddress Farming pool address
    /// @param _uniswapV2Router Uniswap router address
    /// @param _farmingPoolType Farming Pool Type
    /// @param _firstRewardAddress First address for staking rewards
    /// @param _secondRewardAddress Second address for staking rewards
    /// @param _thirdRewardAddress Third address for staking rewards
    /// @return autocompounder struct of data 
    function _deploy(
        address _feeContract,
        address _factory,
        address _farmingPoolAddress,
        address _uniswapV2Router,
        uint8 _farmingPoolType,
        address _firstRewardAddress,
        address _secondRewardAddress,
        address _thirdRewardAddress
    ) internal returns (address autocompounder) {
        parameters = Parameters({
            feeContract: _feeContract,
            factory: _factory,
            farmingPoolAddress: _farmingPoolAddress,
            uniswapV2Router: _uniswapV2Router,
            farmingPoolType: _farmingPoolType,
            firstRewardAddress: _firstRewardAddress,
            secondRewardAddress: _secondRewardAddress,
            thirdRewardAddress: _thirdRewardAddress
        });

        /// one farming pool -> one autocompounder
        autocompounder = address(new AutoCompounder{salt: keccak256(abi.encode(_farmingPoolAddress))}());

        delete parameters;
    }
}
