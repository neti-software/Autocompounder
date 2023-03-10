pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./LEproxyWallet4Position.sol";
import "./../console.sol";
import {WadRayMath} from "./WadRayMath.sol";


//import "contracts/swapContract.sol";
//import "contracts/becomeLiquidityProvider.sol";

interface ISwapContract {
    //    function swapOneHalfForPair(address _token,address _tokenInto,uint _amountIn,uint _amountOutMin) external;
    function swapOneHalfForPair(
        address _token,
        address _tokenInto,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external;

    function swapTokenForPair(
        address _inToken,
        address _outToken0,
        address _outToken1,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external;

    function setNewUniswapV2Router(address _addr) external;

    function getTokenBalance(address _token) external;

    function getBalance() external;

    function swapTokenToToken(
        address _sender,
        address _inToken,
        address _outToken,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external;

    function getPair(address token0, address token1) external returns (address);

    function getTokenPrice(address _targetTokenPrice, address _pricedToken, uint256 _amount) external view returns (uint256);

      function getRewardFromAutocompounder(
        address _token,
        address _autocompounder,
        uint256 _amount
    ) external;

    function withdrawFromAutocompounder(address _autocompounder, uint256 amount) external;
}

interface IBecomeLiquidityProvider {
    function provideLiquidity(
        address _token,
        address _token1,
        uint256 _amount0,
        uint256 _amount1
    ) external;

    function setNewUniswapV2Router(address _addr) external;

    function getTokenBalance(address _token) external;

    function getBalance() external;

    function getPair(address token0, address token1) external returns (address);

    function removeLiquidity(
        address _token,
        address _token1,
        uint256 _amount
    ) external returns (uint256, uint256);
}

/**
@title positionManager contract
@author NETI
@notice Contract represents user interaction with borrowing system, contract is minted per user (address).
    Contract manages process of swapping borrowed token into liquidity pool pair, providing liquidity, deposits LP Tokens to autocompounder 
    and manages repay position process. It holds all information regarding user created positions, repaid amount per position
**/
contract positionManager is AccessControl {
    //  bytes32 public constant WALLET = keccak256("WALLET");
    ISwapContract public swapContract;
    IBecomeLiquidityProvider public becomeLiquidityProvider;
    address public cUSD = address(0);
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using WadRayMath for uint256;
    uint256 public numberOfPositions;
    address public walletAddress;

    //struct RepayBooking { IndexReapyingPosition, ReapyAmount, RepayULPTokensInPool,
    //RepayBorrowToken, LastRepayment, PRIORITYofRepay, IsRepayed }  oraz 2 strukturę PositionRiskEstimation { IndexPosition , RiskLiquidateBorrow, RiskLiquidatePool, GeneralRisks, }
    struct RepayBooking {
        uint256 PositionIndex;
        address positionAddress;
        uint256 RepayAmountToBeDone;
        address RepayULPTokensInPool;
        address RepayBorrowToken;
        uint256 LastRepayment; // block.timestamp
        uint256 PRIORITYofRepay;
        bool IsRepayed;
        bool exists;
    }
    //PositionRiskEstimation { IndexPosition , RiskLiquidateBorrow, RiskLiquidatePool, GeneralRisks, }
    struct PositionRiskEstimation {
        uint256 PositionIndex;
        uint256 RiskLiquidateBorrow;
        uint256 RiskLiquidatePool;
        uint256 GeneralRisks;
        uint256 InitialRisks;
        bool wasLiquidatedByLender;
        bool wasLiquidatedByUser;
        bool wasLiquidatedByOurBot;
        bool exists;
    }

    //
    // swapContract public swapContract;
    // becomeLiquidityProvidor public becomeLiquidityProvider;
    // adress swapa nie bedzie staly Xd
    address public MPMaddress;

    /**
        @dev Creates a new instance of positionManager contract
        @param _walletAddress address of user's wallet - owner of positionManager
        @param  _managerPM address of managerPositionManager 
    **/
    constructor(address _walletAddress, address _managerPM) {
        MPMaddress = msg.sender; // seting up MPM addres during pm minting
        walletAddress = _walletAddress;
        //  _setupRole(ADMIN, ManagerPM);
        //   _setupRole(WALLET, userWalletAdres);
    }

    // ---------- TEST PURPOSES

    /**
        @dev Sets address of swap contract used to swap borrowed amount to liquidity pool pair tokens
        @param _addr address of swap contract
    */
    function setSwapContract(address _addr) external {
        swapContract = ISwapContract(_addr);
    }

    /**
        @dev Sets address of liquidity provider contract 
        @param _addr addres of liquidity provider contract
    */
    function setLiquidityProvider(address _addr) external {
        becomeLiquidityProvider = IBecomeLiquidityProvider(_addr);
    }

    // ----------

    // require(IAccessControl(address(MPM)).hasRole(ADMIN, msg.sender) || hasRole WALLET),msg.sender, "You are not my master");

    ///@dev The function divides the input into 50/50 proportion and swaps 50% into desired Token.
    ///@param _inputToken address of the token which is provided for the divide.
    ///@param _tokenInto address of the token into which the one half will be swaped.
    ///@param _amountIn how much token will be provided.
    ///@param _amountMin The minimum amount of output tokens that must be received for the transaction not to revert.
    function swapTokensHalf(
        address _inputToken,
        address _tokenInto,
        uint256 _amountIn,
        uint256 _amountMin
    ) internal {
        approveTokenIfNeeded(_inputToken, address(swapContract), _amountIn);
        //IERC20(_inputToken).transferFrom(msg.sender,address(this),_amountIn);
        //_amountMin = The minimum amount of output tokens that must be received for the transaction not to revert.

        swapContract.swapOneHalfForPair(_inputToken, _tokenInto, _amountIn, _amountMin);
    }

    ///@dev The function divides the input into 50/50 proportion and swaps one half into _outToken0 and second half into _outToken1.
    ///@param _inputToken address of the token which is provided for the divide.
    ///@param _swapToken0 address of the token into which the one half will be swapped.
    ///@param _swapToken1  address of the token into which the second half will be swapped.
    ///@param _amountIn how much token will be provided.
    ///@param _amountMin The minimum amount of output tokens that must be received for the transaction not to revert.
    function swapTokensFull(
        address _inputToken,
        address _swapToken0,
        address _swapToken1,
        uint256 _amountIn,
        uint256 _amountMin
    ) internal {
        approveTokenIfNeeded(_inputToken, address(swapContract), _amountIn);
        //IERC20(_inputToken).transferFrom(msg.sender,address(this),_amountIn);
        swapContract.swapTokenForPair(_inputToken, _swapToken0, _swapToken1, _amountIn, _amountMin);
    }

    ///@dev The function provides liquidity as a result the LP Tokens are stored in becomeLiquidityProvider contract.
    ///@param _token0 address of token1 for provide liquidity
    ///@param _token1 address of token2 for provide liquidity
    ///@param _amount0 how much token1 will be provided
    ///@param _amount1 how much token2 will be provided
    function provideLiquidity(
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1
    ) internal {
        IERC20(_token0).safeApprove(address(becomeLiquidityProvider), _amount0);
        IERC20(_token1).safeApprove(address(becomeLiquidityProvider), _amount1);
        becomeLiquidityProvider.provideLiquidity(_token0, _token1, _amount0, _amount1);
    }

    // Model of Position
    struct positionInPM {
        uint256 PositionIndex;
        address position;
        address depositToken;
        address borrowToken;
        uint256 borrowAmount;
        uint256 DepositAmount;
        uint256 variableOrStable;
        address token1swap;
        address token2swap;
        address userWallet;
        bool exists;
        uint256 positionDate;
        address[4] autocompounderData;
        uint256 repaidAmount;
        uint256 rewardAmount; 
    }
    mapping(uint256 => positionInPM) public getPositionInPM;
    uint256 LatestPositionIndex = 0;

    struct positionInPMSettings {
        uint256 reinvestRate;
    }
    mapping(uint256 => positionInPMSettings) public getPositionInPMSettings; // positionInPM.PositionIndex => positionInPMSettings


    /**
        @dev First part of position structure creation. Function provides parameters data for new position and creates entry in getPositionInPM mapping
        @param position address of minted position
        @param token1swap address of token1 of pair of 2 that will be transfered to liquidity pool into which part of reward will be swapped
        @param token2swap address of token2 of pair of 2 that will be transfered to liquidity pool into which part of reward will be swapped
        @param depositToken address of collateral (deposit) token
        @param borrowToken address of borrowed asset
        @param borrowAmount amount to be borrowed
        @param DepositAmount amount of collateral
    **/
    function followBorrow1(
        address position,
        address token1swap,
        address token2swap,
        address depositToken,
        address borrowToken,
        uint256 borrowAmount,
        uint256 DepositAmount
    ) external returns (uint256 IndexPosition) {
        LatestPositionIndex = LatestPositionIndex + 1;
        IndexPosition = LatestPositionIndex;
        getPositionInPM[IndexPosition] = positionInPM(
            IndexPosition,
            position,
            depositToken,
            borrowToken,
            borrowAmount,
            DepositAmount,
            0,
            token1swap,
            token2swap,
            address(0x0),
            true,
            0,
            [address(0), address(0), address(0), address(0)],
            0,
            0
        );
    }

    /**
        @dev Second part of position structure creation. Function provides parameters data  to update position. After update position 
            borrowed token is swapped into pair, liquidity is added and LP token is deposited in autocompounder 
        @param IndexPosition index in mapping of previously created position structure
        @param userWallet address of user wallet
        @param autocompounderData autocompounder data array [rewardToken0, rewardToken1, rewardToken2, autocompounder]
            of: rewardToken0, rewardToken1, rewardToken2 - addresses of rewards that autocompounder claims from farm, 
            autocompounder - address of autocompounder
        @param variableOrStable interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
    **/
    function followBorrow2(
        uint256 IndexPosition,
        address userWallet, //    address adresKonta  aka userWallet,
        address[4] memory autocompounderData,
        uint256 variableOrStable,
        uint256 reinvestRate
     ) external returns (bool SuccessfullStoryOfNewPosition) {

         getPositionInPMSettings[IndexPosition].reinvestRate = reinvestRate;

        getPositionInPM[IndexPosition].userWallet = userWallet;
        getPositionInPM[IndexPosition].positionDate = block.timestamp;
        getPositionInPM[IndexPosition].autocompounderData = autocompounderData;
        getPositionInPM[IndexPosition].variableOrStable = variableOrStable;
        uint256 tokenBalance1;
        uint256 tokenBalance2;

        if (getPositionInPM[IndexPosition].token2swap == getPositionInPM[IndexPosition].borrowToken) {
            swapTokensHalf(
                getPositionInPM[IndexPosition].borrowToken,
                getPositionInPM[IndexPosition].token1swap,
                getPositionInPM[IndexPosition].borrowAmount,
                0
            );
            tokenBalance1 = IERC20(getPositionInPM[IndexPosition].token1swap).balanceOf(address(this));
            tokenBalance2 = getPositionInPM[IndexPosition].borrowAmount / 2;
        } else if (getPositionInPM[IndexPosition].token1swap == getPositionInPM[IndexPosition].borrowToken) {
            swapTokensHalf(
                getPositionInPM[IndexPosition].borrowToken,
                getPositionInPM[IndexPosition].token2swap,
                getPositionInPM[IndexPosition].borrowAmount,
                0
            );
            tokenBalance1 = getPositionInPM[IndexPosition].borrowAmount / 2;
            tokenBalance2 = IERC20(getPositionInPM[IndexPosition].token2swap).balanceOf(address(this));
        } else {
            swapTokensFull(
                getPositionInPM[IndexPosition].borrowToken,
                getPositionInPM[IndexPosition].token1swap,
                getPositionInPM[IndexPosition].token2swap,
                getPositionInPM[IndexPosition].borrowAmount,
                0
            );
            tokenBalance1 = IERC20(getPositionInPM[IndexPosition].token1swap).balanceOf(address(this));
            tokenBalance2 = IERC20(getPositionInPM[IndexPosition].token2swap).balanceOf(address(this));
        }
        numberOfPositions++;

        provideLiquidity(
            getPositionInPM[IndexPosition].token1swap,
            getPositionInPM[IndexPosition].token2swap,
            tokenBalance1,
            tokenBalance2
        );
        address lpToken = swapContract.getPair(
            getPositionInPM[IndexPosition].token1swap,
            getPositionInPM[IndexPosition].token2swap
        );

        depositToAutocompounder(
            getPositionInPM[IndexPosition].autocompounderData[3],
            getPositionInPM[IndexPosition].position,
            lpToken
        );
        SuccessfullStoryOfNewPosition = true;
    }

    /**
        @dev Deposit Lp token to autocompounder  
        @param _autocompounder address of autocompounder
        @param _position address of position
        @param _token LP token address to be deposited in autocompounder
    */
    function depositToAutocompounder(
        address _autocompounder,
        address _position,
        address _token
    ) public {
        AutoCompounder ac = AutoCompounder(_autocompounder);
        uint256 balance = IERC20(_token).balanceOf(address(this));
        approveTokenIfNeeded(_token, _autocompounder, type(uint256).max);
        ac.deposit(balance, _position);
    }

    /**
        @dev Clear position in getPositionInPM mapping
        @param IndexPosition index of position in mapping
    */
    function zerowaniePozycji(uint256 IndexPosition) external returns (bool) {
        getPositionInPM[IndexPosition] = positionInPM(
            IndexPosition,
            address(0x0),
            address(0x0),
            address(0x0),
            0,
            0,
            0,
            address(0x0),
            address(0x0),
            address(0x0),
            false,
            0,
            [address(0x0), address(0x0), address(0x0), address(0x0)],
            0,
            0
        );
        return true;
    }

    /*        if(_swapToken0 == cUSD || _swapToken1 == cUSD){
            swapContract.swapOneHalfForPair(_token, _tokenInto, _amountIn, _amountOutMin);
        } else {
            swapContract.swapTokenForPair(_inToken, _outToken0, _outToken1, _amountIn, _amountOutMin);
        }
*/

    //wew -> nadrzedne role z PM
    // require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "Not OWNER");
    // owner == msg sender ?czy? wallet owner ==tx.origin
    // takie wywołanie przyjdzie na starcie  postionManager.FollowDeposit(adres pozycji, msg.sender==userwallet, token1swap, token2swap,borrowToken,depositToken, amount, variableSTABLE==1 (domyślnie teraz bo neiwiemy jak front))
    // listing pozycji ( adres pozycji, token1swap,token2swap, borrowAmount, borrowToken,depositAmount, depositToken,varaibleStable, adresUZYTEGORouter_swapa, adresLiquidiityproviderUzyty, smartContractAddres LP tokenów 1 i 2  )
    // mapping bLP which Router -> address Router to address bLP

    address public constant MoolaPool1 = 0x970b12522CA9b4054807a2c5B736149a5BE6f670;
    /**
        @dev Reinvest position. Function transfers rewards from associated autocompounder, swap it to borrowed token and repay position. 
        @param positionIndex index of position in mapping
    */

    function getRewardsAmountForPosition(uint256 positionIndex) public view returns (uint256 [3] memory){
        positionInPM memory currentPostionToReinvest = getPositionInPM[positionIndex];

        //get rewards token shares for position
        uint256 reward0Amount = 0;
        uint256 reward1Amount = 0;
        uint256 reward2Amount = 0;

        if (currentPostionToReinvest.autocompounderData[0] != address(0)){
            reward0Amount = IERC20(currentPostionToReinvest.autocompounderData[0]).balanceOf(currentPostionToReinvest.autocompounderData[3]); 
        }
        
        if (currentPostionToReinvest.autocompounderData[1] != address(0)) {
            reward1Amount = IERC20(currentPostionToReinvest.autocompounderData[1]).balanceOf(currentPostionToReinvest.autocompounderData[3]); 
        }

        if (currentPostionToReinvest.autocompounderData[2] != address(0)) {
            reward2Amount = IERC20(currentPostionToReinvest.autocompounderData[2]).balanceOf(currentPostionToReinvest.autocompounderData[3]);
        }

        uint256 [3] memory rewardsAmountTbl = [reward0Amount, reward1Amount, reward2Amount];

        return rewardsAmountTbl;

    }

    function reinvestPosition(uint256 positionIndex, uint256 reward0Amount, uint256 reward1Amount, uint256 reward2Amount) public {
        positionInPM storage currentPostionToReinvest = getPositionInPM[positionIndex];
        positionInPMSettings memory currentPostionToReinvestSettings = getPositionInPMSettings[positionIndex];
        
        LEproxyWallet4Position PositionAdr = LEproxyWallet4Position(payable(currentPostionToReinvest.position));
        AutoCompounder ac = AutoCompounder(currentPostionToReinvest.autocompounderData[3]);

        uint256 actualInBorrowToken  = IERC20(currentPostionToReinvest.borrowToken).balanceOf(currentPostionToReinvest.position);  
       
        // uint256 sharesOfPosition = 100;
        // uint256 totalShares = 1000;

        console.log(reward0Amount, "reward0");
        reinvestPositionGetRewards(
            reward0Amount,
            reward1Amount,
            reward2Amount,
            ac.sharesOf(currentPostionToReinvest.position),
            ac.totalSupply(),
            PositionAdr,
            currentPostionToReinvest,
            currentPostionToReinvestSettings.reinvestRate
        ); 
        console.log(actualInBorrowToken, "actul i BT");
        console.log(IERC20(currentPostionToReinvest.borrowToken).balanceOf(currentPostionToReinvest.position), "BT");
        
        uint256 amountToDeposit = IERC20(currentPostionToReinvest.borrowToken).balanceOf(currentPostionToReinvest.position) - actualInBorrowToken;
            
        console.log(amountToDeposit, "Amount to deposit");

        PositionAdr.approveTokenIfNeeded(
                        currentPostionToReinvest.borrowToken,
                        address(this),
                        amountToDeposit
                    );
        IERC20(currentPostionToReinvest.borrowToken).transferFrom(currentPostionToReinvest.position, address(this), amountToDeposit);

        console.log(IERC20(currentPostionToReinvest.borrowToken).balanceOf(address(this)), "BT on this");
        if(amountToDeposit>0){
              depositRewardsToAutocompounder(amountToDeposit, positionIndex);

        }
      
    }

    function reinvestPositionGetRewards(
        uint256 reward0Amount,
        uint256 reward1Amount,
        uint256 reward2Amount,
        uint256 sharesOfPosition,
        uint256 totalSupply,
        LEproxyWallet4Position PositionAdr,
        positionInPM memory currentPostionToReinvest,
        uint256 reinvestRateForCurrentPostionToReinvest
    ) public {

        uint256 rewardinBT = 0;
        if(reward0Amount > 0) {

            console.log(sharesOfPosition, "sharesOF");
            console.log(totalSupply, "totalsupply");

            console.log(IERC20(currentPostionToReinvest.autocompounderData[0]).balanceOf(currentPostionToReinvest.autocompounderData[3]), "r0amount");
            uint256 reward0ToGet = ((sharesOfPosition).wadDiv(totalSupply)).wadMul(reward0Amount);
            console.log(reward0ToGet, "reward0toget");
            
            PositionAdr.getRewardFromAutocompounder(currentPostionToReinvest.autocompounderData[0],currentPostionToReinvest.autocompounderData[3], reward0ToGet);
            console.log(reinvestRateForCurrentPostionToReinvest, "rate");
            uint256 reward0ToReinvest = ((reward0ToGet).wadDiv(100)).wadMul(reinvestRateForCurrentPostionToReinvest);
            console.log(reward0ToReinvest, "reward0toinvest");

            if(currentPostionToReinvest.autocompounderData[0]!=currentPostionToReinvest.borrowToken){
                PositionAdr.approveTokenIfNeeded(
                        currentPostionToReinvest.autocompounderData[0],
                        address(swapContract),
                        reward0ToReinvest
                    );
                    swapContract.swapTokenToToken(
                        currentPostionToReinvest.position,
                        currentPostionToReinvest.autocompounderData[0],
                        currentPostionToReinvest.borrowToken,
                        reward0ToReinvest,
                        0
                    );
            }else{
                rewardinBT += reward0ToReinvest;               
            }
        }
        
        if(reward1Amount > 0) {
            uint256 reward1ToGet = ((sharesOfPosition).wadDiv(totalSupply)).wadMul(reward1Amount);
            PositionAdr.getRewardFromAutocompounder(currentPostionToReinvest.autocompounderData[1],currentPostionToReinvest.autocompounderData[3], reward1ToGet);

            uint256 reward1ToReinvest = ((reward1ToGet).wadDiv(100)).wadMul(reinvestRateForCurrentPostionToReinvest);

            if(currentPostionToReinvest.autocompounderData[1]!=currentPostionToReinvest.borrowToken){
                PositionAdr.approveTokenIfNeeded(
                        currentPostionToReinvest.autocompounderData[1],
                        address(swapContract),
                        reward1ToReinvest
                    );
                    swapContract.swapTokenToToken(
                        currentPostionToReinvest.position,
                        currentPostionToReinvest.autocompounderData[1],
                        currentPostionToReinvest.borrowToken,
                        reward1ToReinvest,
                        0
                    );
            }else{
                rewardinBT += reward1ToReinvest;               
            }
        }
        
        if(reward2Amount > 0) {
            uint256 reward2ToGet = ((sharesOfPosition).wadDiv(totalSupply)).wadMul(reward2Amount);
            PositionAdr.getRewardFromAutocompounder(currentPostionToReinvest.autocompounderData[2],currentPostionToReinvest.autocompounderData[3], reward2ToGet);

            uint256 reward2ToReinvest = ((reward2ToGet).wadDiv(100)).wadMul(reinvestRateForCurrentPostionToReinvest);

                if(currentPostionToReinvest.autocompounderData[2]!=currentPostionToReinvest.borrowToken){
                PositionAdr.approveTokenIfNeeded(
                        currentPostionToReinvest.autocompounderData[2],
                        address(swapContract),
                        reward2ToReinvest
                    );
                    swapContract.swapTokenToToken(
                        currentPostionToReinvest.position,
                        currentPostionToReinvest.autocompounderData[2],
                        currentPostionToReinvest.borrowToken,
                        reward2ToReinvest,
                        0
                    );
            }else{
                rewardinBT += reward2ToReinvest;               
            }
        }

        if(rewardinBT>0)
        {
            PositionAdr.approveTokenIfNeeded(
                        currentPostionToReinvest.borrowToken,
                        address(this),
                        rewardinBT
                    );
        IERC20(currentPostionToReinvest.borrowToken).transferFrom(currentPostionToReinvest.position, address(this), rewardinBT);
        }

        console.log(rewardinBT, "RewardInBT");
    }

      function depositRewardsToAutocompounder(uint256 amount, uint256 positionIndex) public{
        positionInPM memory currentPostionToDeposit = getPositionInPM[positionIndex];

        console.log(amount, "amount");

        uint256 tokenBalance1 = 0;
        uint256 tokenBalance2 = 0;

        console.log(IERC20(currentPostionToDeposit.borrowToken).balanceOf(currentPostionToDeposit.position), "BOF");
        console.log(IERC20(currentPostionToDeposit.borrowToken).balanceOf(address(this)), "BOF this");

        if (currentPostionToDeposit.token2swap == currentPostionToDeposit.borrowToken) {
            swapTokensHalf(
                currentPostionToDeposit.borrowToken,
                currentPostionToDeposit.token1swap,
                amount,
                0
            );
            tokenBalance1 = IERC20(currentPostionToDeposit.token1swap).balanceOf(address(this));
            tokenBalance2 = amount / 2;
        } else if (currentPostionToDeposit.token1swap == currentPostionToDeposit.borrowToken) {
            swapTokensHalf(
                currentPostionToDeposit.borrowToken,
                currentPostionToDeposit.token2swap,
                amount,
                0
            );
            tokenBalance1 = amount / 2;
            tokenBalance2 = IERC20(currentPostionToDeposit.token2swap).balanceOf(address(this));
        } else {
            swapTokensFull(
                currentPostionToDeposit.borrowToken,
                currentPostionToDeposit.token1swap,
                currentPostionToDeposit.token2swap,
                amount,
                0
            );
            tokenBalance1 = IERC20(currentPostionToDeposit.token1swap).balanceOf(address(this));
            tokenBalance2 = IERC20(currentPostionToDeposit.token2swap).balanceOf(address(this));
        }

        console.log(tokenBalance1, "token1balance");
        console.log(tokenBalance2, "token2balance");
        provideLiquidity(
            currentPostionToDeposit.token1swap,
            currentPostionToDeposit.token2swap,
            tokenBalance1,
            tokenBalance2
        );
        address lpToken = swapContract.getPair(
            currentPostionToDeposit.token1swap,
            currentPostionToDeposit.token2swap
        );

        depositToAutocompounder(
            currentPostionToDeposit.autocompounderData[3],
            currentPostionToDeposit.position,
            lpToken
        );
    }

    /**
        @dev Repay position. Function transfers rewards from associated autocompounder, swap it to borrowed token and repay position. 
        @param positionIndex index of position in mapping
    */
    function repayPosition(uint256 positionIndex) public returns (uint256) {
        positionInPM memory currentPostionToRepay = getPositionInPM[positionIndex];
        LEproxyWallet4Position PositionAdr = LEproxyWallet4Position(payable(currentPostionToRepay.position));

        //get rewards token shares for position
        uint256 reward0Amount = 0;
        uint256 reward1Amount = 0;
        uint256 reward2Amount = 0;

        if (currentPostionToRepay.autocompounderData[0] != address(0)){
            reward0Amount = IERC20(currentPostionToRepay.autocompounderData[0]).balanceOf(currentPostionToRepay.position); 
        }
        
        if (currentPostionToRepay.autocompounderData[1] != address(0)) {
            reward1Amount = IERC20(currentPostionToRepay.autocompounderData[1]).balanceOf(currentPostionToRepay.position); 
        }

        if (currentPostionToRepay.autocompounderData[2] != address(0)) {
            reward2Amount = IERC20(currentPostionToRepay.autocompounderData[2]).balanceOf(currentPostionToRepay.position);
        }   
        console.log(reward0Amount, "reward0");
        if (reward0Amount > 0) {
            if(currentPostionToRepay.autocompounderData[0]!=currentPostionToRepay.borrowToken){
                PositionAdr.approveTokenIfNeeded(
                    currentPostionToRepay.autocompounderData[0],
                    address(swapContract),
                    reward0Amount
                );
                swapContract.swapTokenToToken(
                    currentPostionToRepay.position,
                    currentPostionToRepay.autocompounderData[0],
                    currentPostionToRepay.borrowToken,
                    reward0Amount,
                    0
                );
            }
        }

         if (reward1Amount > 0) {
            if(currentPostionToRepay.autocompounderData[1]!=currentPostionToRepay.borrowToken){
                PositionAdr.approveTokenIfNeeded(
                    currentPostionToRepay.autocompounderData[1],
                    address(swapContract),
                    reward1Amount
                );
                swapContract.swapTokenToToken(
                    currentPostionToRepay.position,
                    currentPostionToRepay.autocompounderData[1],
                    currentPostionToRepay.borrowToken,
                    reward1Amount,
                    0
                );
            }
        }

        if (reward2Amount > 0) {
            if(currentPostionToRepay.autocompounderData[2]!=currentPostionToRepay.borrowToken){
                PositionAdr.approveTokenIfNeeded(
                    currentPostionToRepay.autocompounderData[2],
                    address(swapContract),
                    reward2Amount
                );
                swapContract.swapTokenToToken(
                    currentPostionToRepay.position,
                    currentPostionToRepay.autocompounderData[2],
                    currentPostionToRepay.borrowToken,
                    reward2Amount,
                    0
                );
            }
        }
                   
        //@Baney check if safemath will work here
        uint256 repayAmount = IERC20(currentPostionToRepay.borrowToken).balanceOf(currentPostionToRepay.position);

        uint256 positionBalanceInAc = userDepositPositionAmount(positionIndex);
        console.log(positionBalanceInAc, "position balance AC");


        if(repayAmount>0){
            if(positionBalanceInAc>0){
                if(repayAmount > currentPostionToRepay.borrowAmount){
                    uint256 partToInvest = repayAmount - currentPostionToRepay.borrowAmount;
                    repayAmount = currentPostionToRepay.borrowAmount;
                
                    PositionAdr.approveTokenIfNeeded(
                            currentPostionToRepay.borrowToken,
                            address(this),
                            partToInvest
                        );
                    console.log(partToInvest, "Part to invest");
                    IERC20(currentPostionToRepay.borrowToken).transferFrom(currentPostionToRepay.position, address(this), partToInvest);
                    depositRewardsToAutocompounder(partToInvest, positionIndex);
                    getPositionInPMSettings[positionIndex].reinvestRate = 100;

                }
                // repayPositionWithAddress(
                //     PositionAdr,
                //     currentPostionToRepay.borrowToken,
                //     repayAmount,
                //     currentPostionToRepay.variableOrStable
                // );

                uint256 toWithdrawMoola = (repayAmount.wadDiv(currentPostionToRepay.borrowAmount)).wadMul(currentPostionToRepay.DepositAmount); 
                console.log(toWithdrawMoola, "toWithdrawMoola");

                LiquidatePositionAtAddress1RepayAND2Withdraw(
                PositionAdr, 
                currentPostionToRepay.borrowToken,
                repayAmount,
                currentPostionToRepay.variableOrStable,
                currentPostionToRepay.depositToken,
                toWithdrawMoola,
                walletAddress
            );

                // reduce the amount to repay in position
                getPositionInPM[positionIndex].repaidAmount = currentPostionToRepay.repaidAmount + repayAmount;
                getPositionInPM[positionIndex].borrowAmount  = currentPostionToRepay.borrowAmount - repayAmount;
                
          
            }else{
                PositionAdr.approveTokenIfNeeded(
                    currentPostionToRepay.borrowToken,
                    address(this),
                    repayAmount
                );

                IERC20(currentPostionToRepay.borrowToken).transferFrom(currentPostionToRepay.position, walletAddress, repayAmount);
            }
        }

        

        return repayAmount;
    }

    /**
        @dev Repay position in moola
        @param PositionAdr LE proxy walet position
        @param borrowToken address of borrowed asset
        @param repayAmount amount to be re-paid
        @param variableORstable interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
        @return success repay
    */
    function repayPositionWithAddress(
        LEproxyWallet4Position PositionAdr,
        address borrowToken,
        uint256 repayAmount,
        uint256 variableORstable
    ) public returns (bool) {
        IERC20(borrowToken).approve(MoolaPool1, repayAmount);
        uint256 transactionIdRepay = PositionAdr.submitTokenTransactionInMoola(
            borrowToken,
            MoolaPool1,
            repayAmount,
            "MooLaRepay",
            variableORstable
        );
        PositionAdr.confirmTransaction(transactionIdRepay);
        PositionAdr.executeTransaction(transactionIdRepay);

        return true;
    }

    /**
        @dev Repay position in moola
        @param PositionAdr LE proxy walet position
        @param withdrawDepositToken address of collateral deposited asset
        @param withdrawAmount amount to be withdrawed
       @return success repay
    */
    function LiquidatePositionAtAddress2Withdraw(
        LEproxyWallet4Position PositionAdr,
        address withdrawDepositToken,
        uint256 withdrawAmount,
        uint256 variableORstable
    ) public returns (bool) {
        uint256 transactionIdWithdraw = PositionAdr.submitTokenTransactionInMoola(
            withdrawDepositToken,
            MoolaPool1,
            withdrawAmount,
            "MooLaWithdraw",
            variableORstable
        );
        PositionAdr.confirmTransaction(transactionIdWithdraw);
        PositionAdr.executeTransaction(transactionIdWithdraw);

        return true;
    }

    function LiquidatePositionAtAddress1RepayAND2Withdraw(
        LEproxyWallet4Position PositionAdr,
        address borrowToken,
        uint256 repayAmount,
        uint256 variableORstable,
        address withdrawDepositToken,
        uint256 withdrawAmount,
        address whereWithdraw
    ) public returns (bool) {
        // Amount -> Balance of  ?? If bigger than reapyAmount z pozycji
        // 1step Repay
        repayPositionWithAddress(PositionAdr, borrowToken, repayAmount, variableORstable);
        // 2nd step Withdraw
        LiquidatePositionAtAddress2Withdraw(PositionAdr, withdrawDepositToken, withdrawAmount, variableORstable);

        // 3rd step transfer Deposit/collateral tokens to address if 0x0 then it will be PM this address
        if (whereWithdraw == address(0x0)) {
            whereWithdraw = address(this);
        }

        IERC20(withdrawDepositToken).transferFrom(address(PositionAdr), whereWithdraw, withdrawAmount);

        return true;
    }

    /**
        @dev Returns sum of deposited amount in autocompounder (sum for all positions) 
        @param autocompounder address of autocompounder
        @return result sum of deposited amount in autocompounder for all positions
    **/
    function userDepositAmount(address autocompounder) public view returns (uint256) {
        uint256 result = 0;
        AutoCompounder ac = AutoCompounder(autocompounder);
        for (uint8 i = 1; i < numberOfPositions + 1; i++) {
            result += ac.balanceOf(getPositionInPM[i].position);
        }
        return result;
    }
        /**
        @dev Returns deposited amount in autocompounder (declared position) 
        @param positionIndex number of wanted position
        @return result of deposited amount in autocompounder for declared position
    **/
    function userDepositPositionAmount(uint256 positionIndex) public view returns (uint256) {
        uint256 result = 0;
        AutoCompounder ac = AutoCompounder(getPositionInPM[positionIndex].autocompounderData[3]);
        result = ac.balanceOf(getPositionInPM[positionIndex].position);
        return result;
    }


    function withdraw(uint256 positionIndex, uint256 amountToWithdraw, bool withdrawAll) public {
        positionInPM memory currentPostionToWithdraw = getPositionInPM[positionIndex];
        LEproxyWallet4Position PositionAdr = LEproxyWallet4Position(payable(currentPostionToWithdraw.position));
       
        uint256 actualInBorrowToken = 0;
        address acAddress = currentPostionToWithdraw.autocompounderData[3];
        AutoCompounder ac = AutoCompounder(acAddress);

        if(withdrawAll == true){
            amountToWithdraw = ac.balanceOf(currentPostionToWithdraw.position); 
            console.log(amountToWithdraw, "acBalance");
            getPositionInPM[positionIndex].exists = false;
        }
        else{
            actualInBorrowToken = IERC20(currentPostionToWithdraw.borrowToken).balanceOf(currentPostionToWithdraw.position);  
        }
        console.log(withdrawAll, "bool");

        if(amountToWithdraw>0){
    
            PositionAdr.withdrawFromAutocompounder(acAddress, amountToWithdraw);
        
            address ULPPair = becomeLiquidityProvider.getPair(
                currentPostionToWithdraw.token1swap,
                currentPostionToWithdraw.token2swap
            );
            IERC20(ULPPair).safeApprove(address(becomeLiquidityProvider), amountToWithdraw);
            PositionAdr.approveTokenIfNeeded(ULPPair, address(this), amountToWithdraw);
            IERC20(ULPPair).transferFrom(currentPostionToWithdraw.position, address(this), amountToWithdraw);
            (uint256 token1Amount, uint256 token2Amount) = becomeLiquidityProvider.removeLiquidity(
                currentPostionToWithdraw.token1swap,
                currentPostionToWithdraw.token2swap,
                amountToWithdraw
            );
            console.log(token1Amount, "token1Amount");
            console.log(token2Amount, "token2Amount");
            
            if (currentPostionToWithdraw.token1swap != currentPostionToWithdraw.borrowToken) {
                approveTokenIfNeeded(currentPostionToWithdraw.token1swap, address(swapContract), token1Amount);
                swapContract.swapTokenToToken(
                    address(this),
                    currentPostionToWithdraw.token1swap,
                    currentPostionToWithdraw.borrowToken,
                    token1Amount,
                    0
                );
                console.log(IERC20(currentPostionToWithdraw.borrowToken).balanceOf(address(this)), "withdrawAmount1");
            } 

            if (currentPostionToWithdraw.token2swap != currentPostionToWithdraw.borrowToken) {
                approveTokenIfNeeded(currentPostionToWithdraw.token2swap, address(swapContract), token2Amount);
                swapContract.swapTokenToToken(
                    address(this),
                    currentPostionToWithdraw.token2swap,
                    currentPostionToWithdraw.borrowToken,
                    token2Amount,
                    0
                );
                console.log(IERC20(currentPostionToWithdraw.borrowToken).balanceOf(address(this)), "withdrawAmount2");
            }          
        
            uint256 tokenSw = getPMLiquidity(currentPostionToWithdraw.borrowToken);    
            approveTokenIfNeeded(currentPostionToWithdraw.borrowToken, address(this), tokenSw);
            IERC20(currentPostionToWithdraw.borrowToken).transferFrom(
                address(this),
                currentPostionToWithdraw.position,
                tokenSw
            );   
        }
        console.log(IERC20(currentPostionToWithdraw.borrowToken).balanceOf(currentPostionToWithdraw.position), "withdrawAmount");
        
        if(withdrawAll == true) {
            uint256 reward0Amount = IERC20(currentPostionToWithdraw.autocompounderData[0]).balanceOf(
                currentPostionToWithdraw.position
            );
            console.log(reward0Amount, "reward0Amount");
            uint256 reward1Amount = 0;
            uint256 reward2Amount = 0;

            if (currentPostionToWithdraw.autocompounderData[1] != address(0)) {
                reward1Amount = IERC20(currentPostionToWithdraw.autocompounderData[1]).balanceOf(
                    currentPostionToWithdraw.position
                );
                console.log(reward1Amount, "reward1Amount");
            }

            if (currentPostionToWithdraw.autocompounderData[2] != address(0)) {
                reward2Amount = IERC20(currentPostionToWithdraw.autocompounderData[2]).balanceOf(
                    currentPostionToWithdraw.position
                );
                console.log(reward2Amount, "reward2Amount");
            }

            if (reward0Amount > 0) {
                if(currentPostionToWithdraw.autocompounderData[0]!=currentPostionToWithdraw.borrowToken){
                    PositionAdr.approveTokenIfNeeded(
                        currentPostionToWithdraw.autocompounderData[0],
                        address(swapContract),
                        reward0Amount
                    );
                    swapContract.swapTokenToToken(
                        currentPostionToWithdraw.position,
                        currentPostionToWithdraw.autocompounderData[0],
                        currentPostionToWithdraw.borrowToken,
                        reward0Amount,
                        0
                    );
                }
            }

            if (reward1Amount > 0) {
                if(currentPostionToWithdraw.autocompounderData[1]!=currentPostionToWithdraw.borrowToken){
                    PositionAdr.approveTokenIfNeeded(
                        currentPostionToWithdraw.autocompounderData[1],
                        address(swapContract),
                        reward1Amount
                    );
                    swapContract.swapTokenToToken(
                        currentPostionToWithdraw.position,
                        currentPostionToWithdraw.autocompounderData[1],
                        currentPostionToWithdraw.borrowToken,
                        reward1Amount,
                        0
                    );
                }
            }
            if (reward2Amount > 0) {
                if(currentPostionToWithdraw.autocompounderData[2]!=currentPostionToWithdraw.borrowToken){
                    PositionAdr.approveTokenIfNeeded(
                        currentPostionToWithdraw.autocompounderData[2],
                        address(swapContract),
                        reward2Amount
                    );
                    swapContract.swapTokenToToken(
                        currentPostionToWithdraw.position,
                        currentPostionToWithdraw.autocompounderData[2],
                        currentPostionToWithdraw.borrowToken,
                        reward2Amount,
                        0
                    );
                }
            }           
        }

        amountToWithdraw =  IERC20(currentPostionToWithdraw.borrowToken).balanceOf(currentPostionToWithdraw.position) - actualInBorrowToken; 
        console.log(amountToWithdraw, "AmountToWithdraw1");
             
        amountToWithdraw = calculateWithdraw(amountToWithdraw, currentPostionToWithdraw, PositionAdr);
        console.log(amountToWithdraw, "AmountToWithdraw2");

        if(amountToWithdraw > 0){
            uint256 toWithdrawMoola = (amountToWithdraw.wadDiv(currentPostionToWithdraw.borrowAmount)).wadMul(currentPostionToWithdraw.DepositAmount); 
            console.log(toWithdrawMoola, "toWithdrawMoola");

            LiquidatePositionAtAddress1RepayAND2Withdraw(
                PositionAdr, 
                currentPostionToWithdraw.borrowToken,
                amountToWithdraw,
                currentPostionToWithdraw.variableOrStable,
                currentPostionToWithdraw.depositToken,
                toWithdrawMoola,
                walletAddress
            );

            getPositionInPM[positionIndex].repaidAmount = currentPostionToWithdraw.repaidAmount + amountToWithdraw;
            getPositionInPM[positionIndex].DepositAmount = currentPostionToWithdraw.DepositAmount - amountToWithdraw;
            getPositionInPM[positionIndex].borrowAmount = currentPostionToWithdraw.borrowAmount - amountToWithdraw;
            console.log(IERC20(currentPostionToWithdraw.borrowToken).balanceOf(currentPostionToWithdraw.position), "balance after withdraw");
        }
        
    }
    /**
        @dev Calculates repay amount base on moola debt and send rest of borrow asset to user (if withdraw all)
        @param position repaid position
        @param withdrawAmount amount that user requested to withdraw
        @param positionContract position contract instance
        @return withdrawAmount amount to repay moola debt
    **/
    function calculateWithdraw(uint256 withdrawAmount, positionInPM memory position, LEproxyWallet4Position positionContract) private returns(uint256){
           if(withdrawAmount > position.borrowAmount){
                uint256 sendToUserAmount =  withdrawAmount - position.borrowAmount;
                console.log(sendToUserAmount, "sendToUserAmount");

                positionContract.approveTokenIfNeeded(position.borrowToken, address(this), sendToUserAmount);
                IERC20(position.borrowToken).transferFrom(position.position, walletAddress, sendToUserAmount);
                return withdrawAmount - sendToUserAmount;
            }
        return withdrawAmount;
    }

    

    function getPMLiquidity(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function approveTokenIfNeeded(
        address _token,
        address _spender,
        uint256 _amount
    ) public {
        if (IERC20(_token).allowance(address(this), address(_spender)) < _amount) {
            // safeApprove has special check
            IERC20(_token).safeApprove(address(_spender), 0);
            IERC20(_token).safeApprove(address(_spender), type(uint256).max);
        }
    }
    
    function getPositionSumofRewads(uint256 positionIndex) public view returns (uint256) {
        positionInPM memory currentPostionToCheck = getPositionInPM[positionIndex];

        uint256 reward0Amount = 0;
        uint256 reward1Amount = 0;
        uint256 reward2Amount = 0; 
        uint256 swapedRewardSum = 0;
        
        reward0Amount = IERC20(currentPostionToCheck.autocompounderData[0]).balanceOf(currentPostionToCheck.position);
        if(reward0Amount>0){
           uint256 token1= swapContract.getTokenPrice(currentPostionToCheck.borrowToken, currentPostionToCheck.autocompounderData[0], reward0Amount); 
           swapedRewardSum += token1;            
        }
        if(currentPostionToCheck.autocompounderData[1] != address(0)){
            reward1Amount = IERC20(currentPostionToCheck.autocompounderData[1]).balanceOf(currentPostionToCheck.position);
            if(reward1Amount>0){
           uint256 token1= swapContract.getTokenPrice(currentPostionToCheck.borrowToken, currentPostionToCheck.autocompounderData[1], reward1Amount); 
           swapedRewardSum += token1;            
        }
        }

       if(currentPostionToCheck.autocompounderData[2] != address(0)){
            reward2Amount = IERC20(currentPostionToCheck.autocompounderData[2]).balanceOf(currentPostionToCheck.position);
            if(reward2Amount>0){
           uint256 token1= swapContract.getTokenPrice(currentPostionToCheck.borrowToken, currentPostionToCheck.autocompounderData[2], reward2Amount); 
           swapedRewardSum += token1;            
        }
        }
        return swapedRewardSum; 
        
    }

    
    // Udział danej pozycji w puli autocopoundera
    //uint256 positionShares = IERC20(currentPostionToRepay.autocompounderData[3]).sharesOf(currentPostionToRepay.position);
    //uint256 totalShares = IERC20(currentPostionToRepay.autocompounderData[3]).getTotalShares():


    function setReinvestRateInPosition(uint256 positionIndex, uint256 reinvestRate) external {
        getPositionInPMSettings[positionIndex].reinvestRate = reinvestRate;
    }
}
