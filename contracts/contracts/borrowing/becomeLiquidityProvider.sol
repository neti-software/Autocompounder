pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


interface IERC20Symbol {
    function symbol() external returns (string memory);
}

/**
@title BecomeLiquidityProvider contract
@author NETI
@notice Contract responsible for providing liquidity to pool that corresponds with autocompounder. As results sender receives  LP Tokens  
that can be deposited in autocompounder. THis is generic contract and may be used to provide liquidity and receive LP tokens for all protocols
supported by autocompounder.
**/
contract becomeLiquidityProvider {
    IUniswapV2Router02 public uniV2Router;
    using SafeERC20 for IERC20;

    /* ======== EVENTS ======= */
   event ProvideLiquidity(address indexed _from, address indexed _token0, address indexed _token1, uint256 _amount0, uint256 _amount1); 

    ///@dev Initialize becomeLiquidityProvider contract with address of uniswap router where tokens will be swaped.
    ///@param _uniswapRouter router address
    constructor(address _uniswapRouter) {
        uniV2Router = IUniswapV2Router02(_uniswapRouter);
    }
    
    ///@dev Returns balance of native token.
    function getBalance() public view returns(uint256) {
      return address(this).balance;
    }
    ///@dev Returns balance  of token.
    ///@param _token to check balance
    function getTokenBalance(address _token) public view returns(uint256) {
      return IERC20(_token).balanceOf(address(this));
    }
   
    ///@dev Set new uniswap v2 router
    ///@param _addr router address
    function setNewUniswapV2Router(address _addr) external {
        uniV2Router = IUniswapV2Router02(_addr);
    }

    ///@dev approve token function which also checks the allowance
    ///@param _token address of the token to approve.
    ///@param _spender spender
    ///@param _amount how much token will be provided to check allowance.
    function _approveTokenIfNeeded(address _token, address _spender,uint256 _amount) internal {
        if (IERC20(_token).allowance(address(this), address(_spender)) < _amount) {
            // safeApprove has special check
            IERC20(_token).safeApprove(address(_spender), 0);
            IERC20(_token).safeApprove(address(_spender), type(uint256).max);
        }
    }


    ///@dev The function provides liquidity as result the LP Tokens are stored back in contract(self)
    ///@param _token address of tokenA for provide liquidity
    ///@param _token1 address of tokenB for provide liquidity
    ///@param _amount0 how much _tokenA will be provided
    ///@param _amount1 how much _tokenB will be provided
    function provideLiquidity(address _token, address _token1, uint256 _amount0, uint256 _amount1) public {
        //approve tokens and transfer
        _approveTokenIfNeeded(_token,address(uniV2Router), _amount0);
        _approveTokenIfNeeded(_token1,address(uniV2Router), _amount1);
        IERC20(_token).transferFrom(msg.sender,address(this), _amount0);
        IERC20(_token1).transferFrom(msg.sender,address(this), _amount1);
        //pass the balance of provided tokens on contract(self) to addLiquditiy
        uint256 balanaceToken0 = IERC20(_token).balanceOf(address(this));
        uint256 balanceToken1 = IERC20(_token1).balanceOf(address(this));
    
        uniV2Router.addLiquidity(
            _token,
            _token1,
            balanaceToken0,
            balanceToken1, 
            0, // amountAMin
            0, // amountBMin
            msg.sender, //who recives the LP Tokens
            block.timestamp //deadline
            );
        emit ProvideLiquidity(msg.sender, _token, _token1, _amount0, _amount1);
    }

    ///@dev The function removes liquidity and returns the amounts of tokenA and tokenB
    ///@param _token address of tokenA to remove liquidity
    ///@param _token1 address of tokenB to remove liquidity
    ///@param _amount amount of liquidity tokens to remove
    function removeLiquidity(address _token, address _token1, uint256 _amount) public returns (uint256, uint256) {
        address LPPair = getPair(_token, _token1);
        _approveTokenIfNeeded(LPPair, address(uniV2Router), _amount);
        IERC20(LPPair).transferFrom(msg.sender, address(this), _amount);
        return uniV2Router.removeLiquidity(
            _token, 
            _token1,
            _amount,
            0,
            0,
            msg.sender,
            block.timestamp
        );
    }

    ///@dev Returns address of LP token based on pair of tokens addresses
    ///@param token0 address of token0 for that provide liquidity
    ///@param token1 address of token11 for that provide liquidity
    function getPair(address token0, address token1) public view returns (address) {
        IUniswapV2Factory uniV2Factory = IUniswapV2Factory(uniV2Router.factory());
        // get LP pair address for token0 - token1 pair
        return uniV2Factory.getPair(token0, token1);
    }

}