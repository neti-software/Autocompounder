// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV3QuoterV2 {
    function quoteExactInputSingle(
        address, /* tokenIn */
        address, /* tokenOut */
        uint24, /* fee */
        uint256 amountIn,
        uint160 /* sqrtPriceLimitX96 */
    ) public pure returns (uint256 amountOut) {
        return amountIn;
    }
}
