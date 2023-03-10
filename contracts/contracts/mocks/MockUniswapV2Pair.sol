// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract MockUniswapV2Pair {
    address public token0;
    address public token1;

    function setPair(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {}

    function burn(address _to) external returns (uint256 amout0, uint256 amout1) {}
}
