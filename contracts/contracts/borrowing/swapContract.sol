pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

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
    @title swap contract
    @author NETI
    @notice Generic contract that handles all token swap operations in borrowing module.
**/
contract swapContract {
    IUniswapV2Router02 public uniV2Router;
    IUniswapV2Factory public uniswapV2Factory;
    using SafeERC20 for IERC20;

    /* ======== EVENTS ======= */
    event SwapHalf(address indexed _from,address _token,address indexed _tokenInto,uint256 _amountIn,uint256 _amountOutMin);
    event SwapFull(address indexed _from,address _inToken,address indexed _outToken0,address indexed _outToken1,uint256 _amountIn,uint256 _amountOutMin);
    event SwapTokenToToken(address indexed _from,address _token,address indexed _tokenInto,uint256 _amountIn,uint256 _amountOutMin);
   
    /*
    @param _uniswapRouter address of the router where tokens will be swaped
    */
    constructor(address _uniswapRouter) {
        uniV2Router = IUniswapV2Router02(_uniswapRouter);
    }

    /// @dev Set new uniswap v2 router
    /// @param _addr Address of uniswap v2 router
    function setNewUniswapV2Router(address _addr) external {
        uniV2Router = IUniswapV2Router02(_addr);
    }

    // @dev Check native Balance
    function getBalance() public view returns(uint256) {
      return address(this).balance;
    }
    // @dev Check Token Balance
    // @param _token Token to check address
    function getTokenBalance(address _token) public view returns(uint256) {
      return IERC20(_token).balanceOf(address(this));
    }
    //@dev Returns Unisvap factory addres
    function getUniswapFactoryAddress() public view returns(address) {
        return uniV2Router.factory();
    }


    /* ========== SWAP FUNCTIONS ========== */

    ///@dev The function divides the input into 50/50 proportion and swaps 50% into desired Token.
    ///@param _token address of the token which is provided for the divide.
    ///@param _tokenInto address of the token into which the one half will be swaped.
    ///@param _amountIn how much token will be provided.
    ///@param _amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
    function swapOneHalfForPair(address _token,address _tokenInto,uint _amountIn,uint _amountOutMin) public {
        require(IERC20(_token).balanceOf(msg.sender) >= _amountIn,"SC: NET"); // Not Enough Tokens
        // approve router and transfer to contract
        _approveTokenIfNeeded(_token,address(uniV2Router),_amountIn);
        uint256 token0Amount = _amountIn / 2;
        IERC20(_token).transferFrom(msg.sender,address(this),token0Amount);
        uint256 exchangeAmount = _amountIn - token0Amount; //totalTokenBalance - token0Amount

        // Swap on Router
        address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = _tokenInto;
        uniV2Router.swapExactTokensForTokens(
            exchangeAmount, 
            _amountOutMin, 
            path, 
            msg.sender, // where are the swaped token send back to msg.sender
            block.timestamp
            );

        emit SwapHalf(msg.sender,_token,_tokenInto,_amountIn,_amountOutMin);
    }

    
    ///@dev The function divides the input into 50/50 proportion and swaps one half into _outToken0 and second half into _outToken1.
    ///@param _inToken address of the token which is provided for the divide.
    ///@param _outToken0 address of the token into which the one half will be swaped.
    ///@param _outToken1  address of the token into which the second half will beswaped.
    ///@param _amountIn how much token will be provided.
    ///@param _amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
    function swapTokenForPair(address _inToken,address _outToken0, address _outToken1, uint _amountIn, uint _amountOutMin) public {
        _approveTokenIfNeeded(_inToken,address(uniV2Router),_amountIn);
        IERC20(_inToken).transferFrom(msg.sender,address(this),_amountIn);

        //exchange
        uint256 totalTokenBalance = IERC20(_inToken).balanceOf(address(this)); 
        uint256 token0Amount = totalTokenBalance / 2; //one half 
        uint256 exchangeToken1Amount = totalTokenBalance - token0Amount; //second half 

        // First Swap of the first half
        address[] memory path = new address[](2);
            path[0] = _inToken;
            path[1] = _outToken0;
        uniV2Router.swapExactTokensForTokens(token0Amount, _amountOutMin, path, msg.sender, block.timestamp);

        // Swap of the second half
        address[] memory path1 = new address[](2);
            path1[0] = _inToken;
            path1[1] = _outToken1;
        uniV2Router.swapExactTokensForTokens(exchangeToken1Amount, _amountOutMin, path1, msg.sender, block.timestamp);
        
        emit SwapFull(msg.sender,_inToken,_outToken0,_outToken1,_amountIn,_amountOutMin);
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

    /**@dev Function swaps input token into another on output
    @param _inToken address of the token to swap
    @param _outToken address of token to receive
    @param _sender Token owner addres
    @param _amountIn how much token will be provided.
    @param _amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
    */
    function swapTokenToToken(address _sender, address _inToken, address _outToken, uint256 _amountIn, uint _amountOutMin) public {
        _approveTokenIfNeeded(_inToken,address(uniV2Router),_amountIn);
        IERC20(_inToken).transferFrom(_sender,address(this),_amountIn);
        address[] memory path = new address[](2);
            path[0] = _inToken;
            path[1] = _outToken;
        uniV2Router.swapExactTokensForTokens(_amountIn, _amountOutMin, path, _sender, block.timestamp);
        emit SwapTokenToToken(_sender, _inToken, _outToken, _amountIn, _amountOutMin);
    }
    /**
    @dev Function returns address of pair
    @param token0 Address of Token0
    @param token1 Address of Token1
    */
    function getPair(address token0,address token1) public view returns (address) {
        IUniswapV2Factory uniV2Factory = IUniswapV2Factory(uniV2Router.factory());
        return uniV2Factory.getPair(token0, token1);
    }

    function getTokenPrice(address targetTokenPrice, address pricedToken, uint256 amount) public view returns (uint256) {
        if (targetTokenPrice != pricedToken) {
            address pairAddress = getPair(targetTokenPrice, pricedToken);
            IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
            (uint256 Res0, uint256 Res1, ) = pair.getReserves();

            if (targetTokenPrice == pair.token1()) {
                return (amount * Res1) / Res0;
            } else {
                return (amount * Res0) / Res1;
            }
        }
        return 1;
    }
}