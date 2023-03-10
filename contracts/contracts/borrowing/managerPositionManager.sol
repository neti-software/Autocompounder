pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LEproxyWallet4Position.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./positionManager.sol";

/**
@title managerPositionManager contract
@author NETI
@notice Main contract of borrowing module. Contract must be pre-minted and each of borrowing transactions are initialized from it.
    Contract manage all position managers that were minted for each of the users who executed borrow. 
**/
contract managerPositionManager {
    address public constant MoolaPool1 = 0x970b12522CA9b4054807a2c5B736149a5BE6f670;
    mapping(address => address) public positionsManagersList;
    address[] public allManagers;
    //bytes32 public constant ADMIN = keccak256("ADMIN");
    address public tempnewposition = address(0x0);
    address public constant swapContract = 0x88Ab91ed1c25E23e3eB0e97dDc0731F7D869731e;

    /**
    @dev Creates new instance of managerPositionManager contract
     */
    constructor() {}

    /**
    @dev Main function of borrowing process. Executes borrowing base on selected borrow token. Borrowed asset is swapped
     into pair of tokens that are transferred to becomeLiquidityProvider contract. After add liquidity result LP Token is deposited 
     in autocompounder and process of autocompounder is started
    @param token1swap address of token1 of pair of 2 that will be transfered to liquidity pool into which part of reward will be swapped
    @param token2swap address of token2 of pair of 2 that will be transfered to liquidity pool into which part of reward will be swapped
    @param depositToken address of collateral (deposit) token
    @param borrowToken address of borrowed asset
    @param borrowAmount amount to be borrowed
    @param depositAmount amount of collateral
    @param variableORstable interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
    @param autocompounderData autocompounder data array [rewardToken0, rewardToken1, rewardToken2, autocompounder]
     of: rewardToken0, rewardToken1, rewardToken2 - addresses of rewards that autocompounder claims from farm, 
     autocompounder - address of autocompounder
     @return address of positionManager created for caller
    **/

    struct DepositFncParams {
        address token1swap;
        address token2swap;
        address depositToken;
        address borrowToken;
        uint256 borrowAmount;
        uint256 depositAmount;
        uint256 variableORstable;
        address[4] autocompounderData; // [rewardToken0, rewardToken1, rewardToken2, autocompounder]
        uint256 reinvestRate;     
    }

     function deposit( DepositFncParams memory depositFncParams ) external returns (address) {

        // DepositFncParams memory depositFncParams;
        // depositFncParams.token1swap = token1swap;
        // depositFncParams.token2swap = token1swap;
        // depositFncParams.depositToken = depositToken;
        // depositFncParams.borrowToken = borrowToken;
        // depositFncParams.borrowAmount = borrowAmount;
        // depositFncParams.depositAmount = depositAmount;
        // depositFncParams.variableORstable = variableORstable;
        // depositFncParams.autocompounderData = autocompounderData;
        // depositFncParams.reinvestRate = reinvestRate;

        IERC20(depositFncParams.depositToken).transferFrom(
            msg.sender,
            address(this),
            depositFncParams.depositAmount
        );

        address payable adresKonta = payable(checkPositionManager());
        positionManager currentAccount = positionManager(
            checkPositionManager()
        );

        //scoped variables to avoid stack too deep
        address payable ourNewPosition;
        {
            ourNewPosition = payable(newPosition(adresKonta));

            LEproxyWallet4Position adresDoDepozytuAKAadresPosition = LEproxyWallet4Position(
                    ourNewPosition
                );

            IERC20(depositFncParams.depositToken).transfer(ourNewPosition, depositFncParams.depositAmount);
            // tempnewposition = ourNewPosition;

            uint256 transactionIdDeposit = adresDoDepozytuAKAadresPosition
                .submitTokenTransactionInMoola(
                    depositFncParams.depositToken,
                    MoolaPool1,
                    depositFncParams.depositAmount,
                    "MooLaDeposit",
                    depositFncParams.variableORstable
                );
            adresDoDepozytuAKAadresPosition.confirmTransaction(
                transactionIdDeposit
            );
            adresDoDepozytuAKAadresPosition.executeTransaction(
                transactionIdDeposit
            );

            //in logic -> adresDoDepozytuAKAadresPosition.borrow(depositToken, borrowToken,  borrowAmount, depositAmount, variableORstable);
            // in steps => adresDoDepozytuAKAadresPosition.submitTokenTransactionInMoola + confirm + execution
            //   function submitTokenTransactionInMoola(address tokenaddress,address LendingPoolAddress, uint256 value, string memory transactionType)
            // 0x970b12522ca9b4054807a2c5b736149a5be6f670 Hardcoded MooLa lending pool
            uint256 transactionIdBorrow = adresDoDepozytuAKAadresPosition
                .submitTokenTransactionInMoola(
                    depositFncParams.borrowToken,
                    MoolaPool1,
                    depositFncParams.borrowAmount,
                    "MooLaBorrow",
                    depositFncParams.variableORstable
                );
            adresDoDepozytuAKAadresPosition.confirmTransaction(
                transactionIdBorrow
            );
            adresDoDepozytuAKAadresPosition.executeTransaction(
                transactionIdBorrow
            );

            // transfering token
            transactionIdBorrow = adresDoDepozytuAKAadresPosition
                .submitTokenTransaction(depositFncParams.borrowToken, adresKonta, depositFncParams.borrowAmount, depositFncParams.variableORstable);

            adresDoDepozytuAKAadresPosition.confirmTransaction(
                transactionIdBorrow
            );
            adresDoDepozytuAKAadresPosition.executeTransaction(
                transactionIdBorrow
            );
        }
        // -> onBehalf of od razu do PM wysyłamy to co z Borrow dostaniemy,

        // for TEST purposes HARDCODED ADDRESSES
        currentAccount.setLiquidityProvider(
            0x739498fDB69eA902b331e88fBD84e01253681129
        );
        
        currentAccount.setSwapContract(swapContract);

        // ------
        

        uint256 positionIndexInPM = currentAccount.followBorrow1(
            ourNewPosition,
            depositFncParams.token1swap,
            depositFncParams.token2swap,
            depositFncParams.depositToken,
            depositFncParams.borrowToken,
            depositFncParams.borrowAmount,
            depositFncParams.depositAmount
        );

        address adresKontaT = adresKonta;

        bool passingControl2PM = currentAccount.followBorrow2(
            positionIndexInPM,
            adresKontaT,
            depositFncParams.autocompounderData,
            depositFncParams.variableORstable,
            depositFncParams.reinvestRate
        );
        // przekazanie kontroli do positionManagera pod swapa już
        if (!passingControl2PM) {
            currentAccount.zerowaniePozycji(positionIndexInPM);
        }

        return adresKonta;
    }
    /**
    @dev Mint new positionManager for caller or returns existing one if exists for caller address
    @return address of positionManager created for caller
    **/
    function checkPositionManager() internal returns (address) {
        if (positionsManagersList[msg.sender] != address(0x0)) {
            return positionsManagersList[msg.sender];
        } else {
            // new positionManager minting
            positionManager adresKontaPM = new positionManager(
                msg.sender,
                address(this)
            );
            positionsManagersList[msg.sender] = address(adresKontaPM);
            return address(adresKontaPM);
        }
    }

    /**
    @dev Mint new position 
    @param currentAccount address of positin manager that was minted for caller
    @return address of minted position
    **/
    function newPosition(address currentAccount) internal returns (address) {
        LEproxyWallet4Position adresDoDepozytuAKAadresPosition = new LEproxyWallet4Position(
                msg.sender,
                currentAccount,
                address(this),
                1
            );
        return address(adresDoDepozytuAKAadresPosition);
    }

    /**
    @dev Get address of users's positionManager
    @return address of user's positionManager
    **/    function getPositionManager() external view returns (address) {
        return positionsManagersList[msg.sender];
    }

    
}