// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title The interface for a AutoCompounder V2
/// @notice AutoCompounder contract
interface IAutoCompounder {
    /// @notice Deposit function
    /// @param _recipient recipient
    /// @param _amount amount
    function deposit(uint256 _amount, address _recipient) external;

    /// @notice Withdraw function
    /// @param _recipient recipient
    /// @param _liquidity liquidity to withdraw
    function withdraw(address _recipient, uint256 _liquidity) external returns (uint256 amount);

    /// @notice claim reward
    function claimAndFarm() external;
}
