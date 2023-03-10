// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./MockERC20.sol";

contract MockPair {}

contract MockUniswap {
    mapping(address => mapping(address => address)) private _pair;
    uint256 public constant ONE = 10**18;
    uint256 public removeLiquidityAmountA = 20 * ONE;
    uint256 public removeLiquidityAmountB = 20 * ONE;

    uint256 public addLiquidityAmountA = 30 * ONE;
    uint256 public addLiquidityAmountB = 0;
    uint256 public addLiquidityValue = 5 * ONE;

    function addLiquidity(
        address, /* tokenA */
        address, /* tokenB */
        uint256, /* amountADesired */
        uint256, /* amountBDesired */
        uint256, /* amountAMin */
        uint256, /* amountBMin */
        address, /* to */
        uint256 /* deadline */
    )
        external
        view
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        return (addLiquidityAmountA, addLiquidityAmountB, addLiquidityValue);
    }

    function removeLiquidity(
        address, /* tokenA */
        address, /* tokenB */
        uint256, /* liquidity */
        uint256, /* amountAMin */
        uint256, /* amountBMin */
        address, /* to */
        uint256 /* deadline */
    ) external view returns (uint256 amountA, uint256 amountB) {
        return (removeLiquidityAmountA, removeLiquidityAmountB);
    }

    function setRemoveLiquidityValue(uint256 amountA, uint256 amountB) external {
        removeLiquidityAmountA = amountA;
        removeLiquidityAmountB = amountB;
    }

    function setAddLiquidityValue(
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    ) external {
        addLiquidityAmountA = amountA;
        addLiquidityAmountB = amountB;
        addLiquidityValue = liquidity;
    }

    /**
     * @dev set pair address
     *
     * @param token0 token 0
     * @param token1 token 1
     * @param pairAddress the pairAddress correspond to (token0, token1)
     **/
    function setPair(
        address token0,
        address token1,
        address pairAddress
    ) public {
        _pair[token0][token1] = pairAddress;
        _pair[token1][token0] = pairAddress;
    }

    /**
     * @dev get pair address
     *
     * @param token0 token 0
     * @param token1 token 1
     **/
    function getPair(address token0, address token1) public view returns (address) {
        return _pair[token0][token1];
    }

    /**
     * @dev get address uniswap contract factory
     **/
    function factory() public view returns (address) {
        return address(this);
    }
}
