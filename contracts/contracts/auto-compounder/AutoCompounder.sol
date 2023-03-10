// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IAutoCompounderDeployer.sol";
import "./interfaces/IAutoCompounderFactory.sol";
import "./interfaces/IAutoCompounder.sol";
import "./interfaces/IFee.sol";
import "./interfaces/IStakingRewards.sol";
import "../libs/Math.sol";
import "./AutocompounderERC20.sol";


interface IERC20Symbol {
    function symbol() external returns (string memory);
}

///@title Autocompounder contract
///@author NETI
///@notice This is the main contract of the Autocopounder module. Each autocompounder contract represents the connection between protocol (farm) and corresponding pool deposited by users. Pool contains assets that are staked in the protocol, each wallet has its own share in the autocompounder pool. Autocompounder is claiming rewards from corresponding protocol and re-investing pool including rewards or borrowed position is repaid with the amount of position rewards. Autocompounder implements ERC20 standard, after deposit representation in shared pool is transferred to the user as Autocompounder Liquidity Pool tokens.
///@dev
contract AutoCompounder is IAutoCompounder, AutocompounderERC20, ReentrancyGuard, Math {
    using SafeERC20 for IERC20;
    string private _name;
    string private _symbol;

    address public token0; // the first token of farming pool stake LP
    address public token1; // the second token of farming pool stake LP
    address public firstRewardAddress; // reward of farming pool
    address public secondRewardAddress; // reward of farming pool
    address public thirdRewardAddress; // reward of farming pool
    uint8 public farmingPoolType; // farming pool type: single - 1, dual - 2, triple - 3

    IFee public feeContract; // address to collect fee
    IUniswapV2Router02 public uniswapV2Router; // address of uniswap v2 router
    // farming pool address
    IStakingRewards public stakingReward;
    IAutoCompounderFactory public factory; // address of the autocompounder factory

    event Deposit(address indexed user, address indexed receiver, uint256 indexed lpAmount);
    event Withdraw(address indexed user, address indexed receiver, uint256 indexed lpAmount);
    event Fees(uint256 firstRewardAmount, uint256 secondRewardAmount, uint256 thirdRewardAmount);
    event Rewards(uint256 firstRewardAmount, uint256 secondRewardAmount, uint256 thirdRewardAmount);

    /**@dev Contract constructor sets initial values of autocompounder. Set of values is transfered from deployer contract
    @ feeContract Fee contract address,
    @ factory Autocompounder factory address,
    @ farmingPoolAddress,
    @ uniswapV2Router Uniswap router address,
    @ farmingPoolType Farming Pool Typ,
    @ firstRewardAddress First addres for staking rewards,
    @ secondRewardAddress Second addres for staking rewards,
    @ thirdRewardAddress Third addres for staking rewards,
    @ _name Name of Autocompounder liquidity pool token,
    @ _symbol Symbol of Autocompounder liquidity pool token,
    */

    constructor() {
        (
            address _feeContract,
            address _factory,
            address _farmingPoolAddress,
            address _uniswapV2Router,
            uint8 _farmingPoolType,
            address _firstRewardAddress,
            address _secondRewardAddress,
            address _thirdRewardAddress
        ) = IAutoCompounderDeployer(msg.sender).parameters();
        feeContract = IFee(_feeContract);
        factory = IAutoCompounderFactory(_factory);
        stakingReward = IStakingRewards(_farmingPoolAddress);
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        farmingPoolType = _farmingPoolType;
        firstRewardAddress = _firstRewardAddress;
        secondRewardAddress = _secondRewardAddress;
        thirdRewardAddress = _thirdRewardAddress;

        token0 = IUniswapV2Pair(address(stakingReward.stakingToken())).token0();
        token1 = IUniswapV2Pair(address(stakingReward.stakingToken())).token1();

        _name = string(
            abi.encodePacked(
                IERC20Symbol(token0).symbol(),
                "-",
                IERC20Symbol(token1).symbol(),
                "-",
                Strings.toString(farmingPoolType),
                " AutoCompounder LP Token"
            )
        );

        _symbol = string(
            abi.encodePacked(
                IERC20Symbol(token0).symbol(),
                "-",
                IERC20Symbol(token1).symbol(),
                "-",
                Strings.toString(farmingPoolType),
                " ALP"
            )
        );

        // approve LPToken
        _approveTokenIfNeeded(_getPair(), address(stakingReward), type(uint256).max);

        // approve UBE and CELOAddress for router
        _approveTokenIfNeeded(token0, address(uniswapV2Router), type(uint256).max);
        _approveTokenIfNeeded(token1, address(uniswapV2Router), type(uint256).max);
        _approveTokenIfNeeded(firstRewardAddress, address(uniswapV2Router), type(uint256).max);

        // Check is there first reward address
        if (firstRewardAddress != address(0)) {
            _approveTokenIfNeeded(firstRewardAddress, address(uniswapV2Router), type(uint256).max);
        }

        // If not single reward, approve 2 remain rewards
        if (secondRewardAddress != address(0)) {
            _approveTokenIfNeeded(secondRewardAddress, address(uniswapV2Router), type(uint256).max);
        }
        if (thirdRewardAddress != address(0)) {
            _approveTokenIfNeeded(thirdRewardAddress, address(uniswapV2Router), type(uint256).max);
        }
    }

    
    /// @dev Returns the name of the token.
    /// @return _name Name of the token 
     
     function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     * @return _symbol Symbol name
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc IAutoCompounder
    /// @dev Deposit LP tokens
    /// @notice returnLiquidity - Autocompounder liquidity poll token for user
    /// @param _amount Amount of User LP tokens
    /// @param _recipient User addres for ALP tokens
    function deposit(uint256 _amount, address _recipient) external override nonReentrant {
        // claimReward and farm
        _claimAndFarm();

        // calculate ALP: userLP/(totalLP + reward)
        uint256 returnLiquidity = _calLiquidity(_amount);

        // get LP token from User
        IERC20(_getPair()).safeTransferFrom(msg.sender, address(this), _amount);
        _farm();

        // send ALP token to _recipient
        _mintShares(_recipient, returnLiquidity);

        //approve revards for position(if exists)      
        if (firstRewardAddress != address(0)) {
            _approveTokenIfNeeded(firstRewardAddress, _recipient, type(uint256).max);
        }

        // If not single reward, approve 2 remain rewards
        if (secondRewardAddress != address(0)) {
            _approveTokenIfNeeded(secondRewardAddress, _recipient, type(uint256).max);
        }
        if (thirdRewardAddress != address(0)) {
            _approveTokenIfNeeded(thirdRewardAddress, _recipient, type(uint256).max);
        }
        emit Deposit(msg.sender, _recipient, _amount);
    }

    /// @inheritdoc IAutoCompounder
    /// @dev Withdraw balance to the user. Rewards that are not re-invested are transferred to user 
    /// @param _recipient User addres to withdraw
    /// @param _liquidity User ALP amount
    /// @return amount User balance to withdraw
    function withdraw(address _recipient, uint256 _liquidity) external override nonReentrant returns (uint256 amount) {
        require(_liquidity <= balanceOf(msg.sender), "AC: NEA"); // not enough amount
        require(_liquidity > 0, "AC: NP"); // not positive

        // calculate ratio and send to user
        uint256 ratio = bdiv(_liquidity, totalSupply());

        // _burnShares(msg.sender, _alpToShares(_liquidity));
        _burnShares(msg.sender, _liquidity);

        // claim reward
        if (stakingReward.balanceOf(address(this)) > 0) {
            _claimReward();
            _sendReward(firstRewardAddress, ratio, _recipient);
            _sendReward(secondRewardAddress, ratio, _recipient);
            _sendReward(thirdRewardAddress, ratio, _recipient);
        }

        stakingReward.withdraw(bmul(ratio, stakingReward.balanceOf(address(this))));

        IERC20 pair = IERC20(_getPair());
        amount = pair.balanceOf(address(this));
        pair.safeTransfer(_recipient, amount);

        emit Withdraw(msg.sender, _recipient, _liquidity);
    }

    /// @inheritdoc IAutoCompounder
    // in a period time, backend job will call this func and trade
    ///@dev  Claim and farm function. Responsible for claim rewards from staking protocol, swap to LP token and re-invest
    function claimAndFarm() external override {
        _claimAndFarm();
    }

    /// @dev Claim rewards
    /// @param _recipient Recipient address for rewards
    function claim(address _recipient) external nonReentrant {
        if (stakingReward.balanceOf(address(this)) <= 0) return;

        uint256 ratio = bdiv(balanceOf(msg.sender), totalSupply());
        _claimReward();
        _sendReward(firstRewardAddress, ratio, _recipient);
        _sendReward(secondRewardAddress, ratio, _recipient);
        _sendReward(thirdRewardAddress, ratio, _recipient);
    }

    /**
     * @dev Withdraw without caring about rewards. EMERGENCY ONLY.
     * @param _receiver receiver address
     * @param _token token address which want to withdraw
     */
    function emergencyWithdraw(address _receiver, address _token) external {
        require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "AC: ADR"); // admin role
        IERC20(_token).safeTransfer(_receiver, IERC20(_token).balanceOf(address(this)));
    }

    /// @dev Set fee contract address
    /// @param _fee Fee contract address
    function setFeeAddress(address _fee) external {
        require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "AC: ADR"); // admin role
        feeContract = IFee(_fee);
    }

    /// @dev set farming pool type: single - 1, dual - 2, triple - 3. Farm pool type corresponds to number of reward tokens that are claimed from staking protocol
    /// @param _farmingPoolType Farmin pool type
    function setFarmingPoolType(uint8 _farmingPoolType) external {
        require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "AC: ADR"); // admin role
        farmingPoolType = _farmingPoolType;
    }

    /// @dev Set uniswap v2 router address
    /// @param _uniswapV2Router Uniswap v2 router address
    function setUniswapV2Router(IUniswapV2Router02 _uniswapV2Router) external {
        require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "AC: ADR"); // admin role
        uniswapV2Router = _uniswapV2Router;
    }

    /// @dev Set first token reward address
    /// @param _firstRewardAddress First reward address
    function setFirstRewardAddress(address _firstRewardAddress) external {
        require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "AC: ADR"); // admin role
        firstRewardAddress = _firstRewardAddress;
    }

    /// @dev Set second token reward address
    /// @param _secondRewardAddress Second reward address
    function setSecondRewardAddress(address _secondRewardAddress) external {
        require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "AC: ADR"); // admin role
        secondRewardAddress = _secondRewardAddress;
    }

    /// @dev Set third token reward address
    /// @param _thirdRewardAddress Third reward address
    function setThirdRewardAddress(address _thirdRewardAddress) external {
        require(IAccessControl(address(factory)).hasRole(ADMIN, msg.sender), "AC: ADR"); // admin role
        thirdRewardAddress = _thirdRewardAddress;
    }
    /// @dev Information about Total Pooled Autocompounder liquidity pool tokens 
    /// @return total pooled LP tokens in staking protocol
    function _getTotalPooledALP() internal view override returns (uint256) {
        return stakingReward.balanceOf(address(this));
    }

    /// @dev Claim rewards, convert back to LP and stake to farming pool
    function _claimAndFarm() private {
        if (stakingReward.balanceOf(address(this)) > 0) {
            _claimReward();
           // _convertReward(); //rewards are for now not converted - will be to possition to repay debt or convert it and send to autocompounder
        }
        _farm();
    }

    /// @dev Convert back to LP tokens
    function _convertReward() private {   
        if (firstRewardAddress != address(0)) {
            _convertTokenToLP(firstRewardAddress);
        }

        // dual rewards
        if (secondRewardAddress != address(0)) {
            _convertTokenToLP(secondRewardAddress);
        }
        // triple rewards
        if (thirdRewardAddress != address(0)) {
            _convertTokenToLP(thirdRewardAddress);
        }

        _addLiquidity();
    }

    /// @dev Calculate the ALP corresponding to LP Token
    /// @param _userLiquidity User liquidity pool tokens
    /// @return amount of ALP
    function _calLiquidity(uint256 _userLiquidity) private view returns (uint256) {
        if (totalSupply() == 0) {
            return _userLiquidity;
        }
        // balance of stakingReward = amount of LP Tokens staked
        uint256 ratio = bdiv(_userLiquidity, stakingReward.balanceOf(address(this)));
        return bmul(ratio, totalSupply());
    }

    /// @dev Claim rewards from farming pool
    function _claimReward() private {
        stakingReward.getReward();
        _transferFee();
    }

    /// @dev When claim rewards, send fee to fee contract
    function _transferFee() private {
        uint256 fee1;
        uint256 fee2;
        uint256 fee3;
        uint256 reward1;
        uint256 reward2;
        uint256 reward3;

        if (firstRewardAddress != address(0)) {
            reward1 = IERC20(firstRewardAddress).balanceOf(address(this));
            fee1 = feeContract.getFee(IERC20(firstRewardAddress).balanceOf(address(this)));
            if (fee1 > 0) IERC20(firstRewardAddress).safeTransfer(address(feeContract), fee1);
        }
        if (secondRewardAddress != address(0)) {
            reward2 = IERC20(secondRewardAddress).balanceOf(address(this));
            fee2 = feeContract.getFee(IERC20(secondRewardAddress).balanceOf(address(this)));
            if (fee2 > 0) IERC20(secondRewardAddress).safeTransfer(address(feeContract), fee2);
        }
        if (thirdRewardAddress != address(0)) {
            reward3 = IERC20(thirdRewardAddress).balanceOf(address(this));
            fee3 = feeContract.getFee(IERC20(thirdRewardAddress).balanceOf(address(this)));
            if (fee3 > 0) IERC20(thirdRewardAddress).safeTransfer(address(feeContract), fee3);
        }

        emit Rewards(reward1, reward2, reward3);
        emit Fees(fee1, fee2, fee3);
    }
     /// @dev Convert rewards to LP tokens
     /// @param _token Claimed reward 
    function _convertTokenToLP(address _token) private {
        // convert 50% to token0, 50% to token1
        uint256 totalTokenBalance = IERC20(_token).balanceOf(address(this));

        if (totalTokenBalance > 0) {
            _approveTokenIfNeeded(_token, address(uniswapV2Router), totalTokenBalance);
            uint256 token0Amount = totalTokenBalance / 2;
            _exchange(_token, token0, token0Amount);
            _exchange(_token, token1, totalTokenBalance - token0Amount);
        }
    }
    ///@dev Adding liquidity to pool
    function _addLiquidity() private {
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        if (token0Balance > 0 && token1Balance > 0) {
            _approveTokenIfNeeded(token0, address(uniswapV2Router), token0Balance);
            _approveTokenIfNeeded(token1, address(uniswapV2Router), token1Balance);
            uniswapV2Router.addLiquidity(
                token0,
                token1,
                token0Balance,
                token1Balance,
                0,
                0,
                address(this),
                _getDeadline()
            );
        }
    }

    /// @dev Exchange _fromToken to _toToken
    /// @param _fromToken from token
    /// @param _toToken to token
    /// @param _amount from token amount
    function _exchange(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) private {
        if (_fromToken != _toToken) {
            address[] memory path = new address[](2);
            path[0] = _fromToken;
            path[1] = _toToken;

            // swap _fromToken to _toToken with amount is _amount
            uniswapV2Router.swapExactTokensForTokens(_amount, 0, path, address(this), _getDeadline());
        }
    }

    /// @dev Stake LP AutoCompounder lp tokens pool
    function _farm() private {
        address lpAddr = _getPair();
        uint256 lpAmount = IERC20(lpAddr).balanceOf(address(this));
        if (lpAmount > 0) {
            _approveTokenIfNeeded(lpAddr, address(stakingReward), lpAmount);
            // stake LP to farm
            stakingReward.stake(lpAmount);
        }
    }

    /// @dev Returns the Tokens pair corresponding to this AutoCompounder
    /// @return address of Tokens pair
    function _getPair() public view returns (address) {
        IUniswapV2Factory uniV2Factory = IUniswapV2Factory(factory.uniswapV2Factory());
        // get LP pair address for token0 - token1 pair
        return uniV2Factory.getPair(token0, token1);
    }

    /// @dev if allowace < transfer amount => approve max
    /// @param token Token address
    /// @param spender Spender address
    /// @param amount Amount to approve
    function _approveTokenIfNeeded(
        address token,
        address spender,
        uint256 amount
    ) private {
        if (IERC20(token).allowance(address(this), address(spender)) < amount) {
            // safeApprove has special check
            IERC20(token).safeApprove(address(spender), 0);
            IERC20(token).safeApprove(address(spender), type(uint256).max);
        }
    }

    /// @dev Send rewards to user after transfer fee to admin address
    /// @param _rewardTokenAddress Reward token address
    /// @param _ratio Token ratio
    /// @param _recipient Recipient address
    function _sendReward(
        address _rewardTokenAddress,
        uint256 _ratio,
        address _recipient
    ) private {
        if (_rewardTokenAddress != address(0) && IERC20(_rewardTokenAddress).balanceOf(address(this)) > 0) {
            IERC20(_rewardTokenAddress).safeTransfer(
                _recipient,
                bmul(IERC20(_rewardTokenAddress).balanceOf(address(this)), _ratio)
            );
        }
    }
    ///@dev Return part of ALP to share
    ///@param - User ALP amount 
    function _alpToShares(uint256 _amount) private view returns (uint256) {
        uint256 denominator = bmul(_amount, _getTotalShares());
        return bdiv(denominator, _getTotalPooledALP());
    }
    ///@dev Returns deadline date
    ///@return Actual timie + 1800
    function _getDeadline() private view returns (uint256) {
        return block.timestamp + 1800;
    }
}
