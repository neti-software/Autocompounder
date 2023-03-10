// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title The interface for a Fee Contract
interface IFee {
    function getFee(uint256 _inputAmount) external returns (uint256 fee);

    function collectFee(address _receiver, address _token) external;
}
