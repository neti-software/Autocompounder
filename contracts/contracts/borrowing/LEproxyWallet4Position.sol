pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @dev Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
     * already deposited enough collateral, or he was given enough allowance by a credit delegator on the
     * corresponding debt token (StableDebtToken or VariableDebtToken)
     * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
     *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
     * @param asset The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     * @param onBehalfOf Address of the user who will receive the debt. Should be the address of the borrower itself
     * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
     * if he has been given credit delegation allowance
     **/
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
     * @param asset The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param rateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
     * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
     * user calling the function if he wants to reduce/remove his own debt, or the address of any other
     * other borrower whose debt should be removed
     * @return The final amount repaid
     **/
    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);
}

interface AutoCompounder {
    function deposit(uint256 _amount, address _recipient) external;

    function withdraw(address _recipient, uint256 _liquidity) external;

    function sharesOf(address _account) external view returns (uint256);

    function getTotalShares() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _account) external view returns (uint256);
}

abstract contract ERC20Interface {
    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address tokenOwner) public view virtual returns (uint256 balance);

    function allowance(address tokenOwner, address spender) public view virtual returns (uint256 remaining);

    function transfer(address to, uint256 tokens) public virtual returns (bool success);

    function approve(address spender, uint256 tokens) public virtual returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) public virtual returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
}

/**
@title position contract
@author NETI
@notice Contract represents user borrow in borrowing service
**/
contract LEproxyWallet4Position {
    using SafeERC20 for IERC20;
    /*
     *  Events
     */
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Submission(uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);
    event Deposit(address indexed sender, uint256 value);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);

    /*
     *  Events
     */

    event DepositInMoola(address indexed sender, uint256 value);
    event submitTokenAllowance(address indexed tokenaddress, address indexed destination, uint256 value);

    /*
     *  View
     */
    uint256 public MAX_OWNER_COUNT = 3;

    /*
     *  Storage
     */
    // address immutable MooLaLendingPool = "";

    mapping(uint256 => Transaction) public transactions;

    mapping(uint256 => mapping(address => bool)) public confirmations;
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;

    struct Transaction {
        address tokenaddress;
        address destination;
        uint256 value;
        bool executed;
        string transactionType;
        uint256 variableORStable;
    }

    /*
     *  Modifiers
     */
    modifier onlyWallet() {
        require(msg.sender == address(this));
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner]);
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner]);
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactions[transactionId].destination != address(0));
        _;
    }

    modifier confirmed(uint256 transactionId, address owner) {
        require(confirmations[transactionId][owner]);
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner) {
        require(!confirmations[transactionId][owner]);
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed);
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0));
        _;
    }

    modifier validRequirement(uint256 ownerCount, uint256 _required) {
        require(ownerCount <= MAX_OWNER_COUNT && _required <= ownerCount && _required != 0 && ownerCount != 0);
        _;
    }

    /// @dev receive function allows to deposit ether.
    receive() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    /*
     * Public functions
     */

    /**
        @dev Creates position that represents user borrow in borrow service
        @param owner1 owner address
        @param owner2 owner address
        @param owner3 owner address
        @param _required Number of required confirmations.
    */
    constructor(
        address owner1,
        address owner2,
        address owner3,
        uint256 _required
    ) {
        isOwner[owner1] = true;
        isOwner[owner2] = true;
        isOwner[owner3] = true;
        owners = [owner1, owner2, owner3];
        required = _required;
    }

    /// @dev Allows to add a new owner. Transaction has to be sent by wallet.
    /// @param owner Address of new owner.
    function addOwner(address owner)
        public
        onlyWallet
        ownerDoesNotExist(owner)
        notNull(owner)
        validRequirement(owners.length + 1, required)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /// @dev Allows to remove an owner. Transaction has to be sent by wallet.
    /// @param owner Address of owner.
    function removeOwner(address owner) public onlyWallet ownerExists(owner) {
        if (msg.sender != owner) revert(); // u can remove only yourself

        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++)
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        if (required > owners.length - 1) changeRequirement(owners.length - 1);
        emit OwnerRemoval(owner);
    }

    /// @dev Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
    /// @param owner Address of owner to be replaced.
    /// @param newOwner Address of new owner.
    function replaceOwner(address owner, address newOwner)
        public
        onlyWallet
        ownerExists(owner)
        ownerDoesNotExist(newOwner)
    {
        if (msg.sender != owner) revert(); // u can replace only yourself

        for (uint256 i = 0; i < owners.length; i++)
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        isOwner[owner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    /// @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
    /// @param _required Number of required confirmations.
    function changeRequirement(uint256 _required) public onlyWallet validRequirement(owners.length, _required) {
        required = _required;
        emit RequirementChange(_required);
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param interestRateMode Interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
    /// @return transactionId Returns transaction ID.
    function submitTransaction(address destination, uint256 value, uint256 interestRateMode)
        public
        ownerExists(msg.sender)
        returns (uint256 transactionId)
    {
        transactionId = addTransaction(destination, value * 1 ether, interestRateMode);
        return transactionId;
    }

    /** @dev Submit and confirm a transaction
        @param value borrow amount
        @param tokenaddress address of token
        @param destination Transaction target address.
        @param interestRateMode Interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
        @return transactionId  ID of transaction
    */
    function submitTokenTransaction(
        address tokenaddress,
        address destination,
        uint256 value,
        uint256 interestRateMode
    )
        public
        returns (
            //    ownerExists(msg.sender)
            uint256 transactionId
        )
    {
        transactionId = addTokenTransaction(tokenaddress, destination, value, interestRateMode);
        return transactionId;
    }

    /**
        @dev Sends borrow transaction to moola borrowing service
        @param tokenaddress address of borrow token
        @param LendingPoolAddress address of lending pool.
        @param value borrow amount
        @param transactionType type of transaction
        @param interestRateMode interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
        @return transactionId ID of transaction
     */
    function submitTokenTransactionInMoola(
        address tokenaddress,
        address LendingPoolAddress,
        uint256 value,
        string memory transactionType,
        uint256 interestRateMode
    )
        public
        returns (
            //   ownerExists(msg.sender)
            uint256 transactionId
        )
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            tokenaddress: tokenaddress,
            destination: LendingPoolAddress, // or hardcoded Moola Lending pool Smartcontract Address deployed on blockchain
            value: value,
            executed: false,
            transactionType: transactionType,
            variableORStable: interestRateMode
        });
        transactionCount += 1;
        emit Submission(transactionId);
        return transactionId;
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint256 transactionId)
        public
        //  ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint256 transactionId)
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint256 transactionId) public notExecuted(transactionId) {
        if (isConfirmed(transactionId)) {
            Transaction storage txn = transactions[transactionId];
            // uint valuoftransaction =txn.value;
            if (keccak256(bytes(txn.transactionType)) == keccak256(bytes("transfer"))) {
                if (txn.tokenaddress == address(0)) {
                    //beneficiary.send(address(this).balance);
                    txn.executed = true;
                    bool sent = payable(txn.destination).send(txn.value);
                    if (sent) emit Execution(transactionId);
                    else {
                        emit ExecutionFailure(transactionId);
                        txn.executed = false;
                    }
                } else {
                    bool tokenSendt = sendTokenAway(txn.tokenaddress, txn.destination, txn.value);
                    if (tokenSendt) {
                        txn.executed = true;
                        emit Execution(transactionId);
                    } else {
                        emit ExecutionFailure(transactionId);
                        txn.executed = false;
                    }
                }
            } else {
                if (keccak256(bytes(txn.transactionType)) == keccak256(bytes("MooLaDeposit"))) {
                    //chyba ze hardkodowac od razu destination = MoolalendingPool address
                    //   txn.tokenaddress is  from ERC20Interface;
                    ERC20Interface TokenContract = ERC20Interface(txn.tokenaddress);
                    TokenContract.approve(txn.destination, txn.value);
                    uint256 setAllowance2MooLA = TokenContract.allowance(address(this), txn.destination);

                    if (setAllowance2MooLA > 0) {
                        //ILendingPool

                        ILendingPool MoolaLendingPool = ILendingPool(txn.destination);
                        MoolaLendingPool.deposit(txn.tokenaddress, txn.value, address(this), 0);

                        txn.executed = true;
                        emit Execution(transactionId);
                    } else {
                        emit ExecutionFailure(transactionId);
                        txn.executed = false;
                    }
                }
                // BORROW
                if (keccak256(bytes(txn.transactionType)) == keccak256(bytes("MooLaBorrow"))) {
                    ILendingPool MoolaLendingPool = ILendingPool(txn.destination);

                    MoolaLendingPool.borrow(txn.tokenaddress, txn.value, txn.variableORStable, 0, address(this));

                    txn.executed = true;
                    emit Execution(transactionId);
                }
                // REPAY
                if (keccak256(bytes(txn.transactionType)) == keccak256(bytes("MooLaRepay"))) {
                    ERC20Interface TokenContract = ERC20Interface(txn.tokenaddress);
                    TokenContract.approve(txn.destination, txn.value);
                    ILendingPool MoolaLendingPool = ILendingPool(txn.destination);

                    /*
                                    function repay(
                        address asset,
                        uint256 amount,
                        uint256 rateMode,
                        address onBehalfOf
                    ) external returns (uint256); */

                    MoolaLendingPool.repay(txn.tokenaddress, txn.value, txn.variableORStable, address(this));

                    txn.executed = true;
                    emit Execution(transactionId);
                }
                // Liquidate position , destroy position in Moola by repay borrowed asset and withdraw collateral

                if (keccak256(bytes(txn.transactionType)) == keccak256(bytes("MooLaWithdraw"))) {
                    ILendingPool MoolaLendingPool = ILendingPool(txn.destination);

                    MoolaLendingPool.withdraw(txn.tokenaddress, txn.value, address(this));

                    ERC20Interface TokenContract = ERC20Interface(txn.tokenaddress);
                    // here address(msg.sender) should be PM which should have option to transfer token to him or user wallet address
                    TokenContract.approve(address(msg.sender), txn.value);
                    txn.executed = true;
                    emit Execution(transactionId);
                }
            }
        }
    }

    // call has been separated into its own function in order to take advantage
    // of the Solidity's code generator to produce a loop that copies tx.data into memory.
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint256 transactionId) public view returns (bool) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) count += 1;
        }
        if (count >= required) {
            return true;
        } else {
            return false;
        }
    }

    /**
        @dev Retrurns information if transactino is executed
        @param transactionId id of transaction to be checked
        @return true if transaction is executed, false if not
     */
    function isExecuted(uint256 transactionId) public view returns (bool) {
        return transactions[transactionId].executed;
    }

    /*
     * Internal functions
     */
    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param interestRateMode Interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
    /// @return transactionId Returns transaction ID.
    function addTransaction(address destination, uint256 value, uint256 interestRateMode)
        internal
        notNull(destination)
        returns (uint256 transactionId)
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            tokenaddress: address(0),
            destination: destination,
            value: value,
            executed: false,
            transactionType: "transfer",
            variableORStable: interestRateMode
        });
        transactionCount += 1;
        emit Submission(transactionId);
        return transactionId;
    }

    /**
        @dev Adds new transaction to transactions mapping
        @param tokenaddress address og borrowed token
        @param destination destination of borrow
        @param value borrow value
        @param interestRateMode interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
        @return transactionId id of created transaction
     */
    function addTokenTransaction(
        address tokenaddress,
        address destination,
        uint256 value,
        uint256 interestRateMode
    ) internal notNull(destination) returns (uint256 transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            tokenaddress: tokenaddress,
            destination: destination,
            value: value,
            executed: false,
            transactionType: "transfer",
            variableORStable: interestRateMode
        });
        transactionCount += 1;
        emit Submission(transactionId);
        return transactionId;
    }

    /*
     * Web3 call functions
     */
    /// @dev Returns number of confirmations of a transaction.
    /// @param transactionId Transaction ID.
    /// @return count Number of confirmations.
    function getConfirmationCount(uint256 transactionId) public view returns (uint256 count) {
        for (uint256 i = 0; i < owners.length; i++) if (confirmations[transactionId][owners[i]]) count += 1;
        return count;
    }

    /// @dev Returns total number of transactions after filers are applied.
    /// @param pending Includes pending transactions.
    /// @param executed Include executed transactions.
    /// @return count Total number of transactions after filters are applied.
    function getTransactionCount(bool pending, bool executed) public view returns (uint256 count) {
        for (uint256 i = 0; i < transactionCount; i++)
            if ((pending && !transactions[i].executed) || (executed && transactions[i].executed)) count += 1;

        return count;
    }

    /// @dev Returns list of owners.
    /// @return List of owner addresses.
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /// @dev Returns array with owner addresses, which confirmed transaction.
    /// @param transactionId Transaction ID.
    /// @return _confirmations -> Returns array of owner addresses.
    function getConfirmations(uint256 transactionId) public view returns (address[] memory _confirmations) {
        address[] memory confirmationsTemp = new address[](owners.length);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < owners.length; i++)
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        _confirmations = new address[](count);
        for (i = 0; i < count; i++) _confirmations[i] = confirmationsTemp[i];
        return _confirmations;
    }

    /// @dev Returns list of transaction IDs in defined range.
    /// @param from Index start position of transaction array.
    /// @param to Index end position of transaction array.
    /// @param pending Include pending transactions.
    /// @param executed Include executed transactions.
    /// @return _transactionIds Returns array of transaction IDs.
    function getTransactionIds(
        uint256 from,
        uint256 to,
        bool pending,
        bool executed
    ) public view returns (uint256[] memory _transactionIds) {
        uint256[] memory transactionIdsTemp = new uint256[](transactionCount);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < transactionCount; i++)
            if ((pending && !transactions[i].executed) || (executed && transactions[i].executed)) {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        _transactionIds = new uint256[](to - from);
        for (i = from; i < to; i++) _transactionIds[i - from] = transactionIdsTemp[i];

        return _transactionIds;
    }

    /**
        @dev approve token function which also checks the allowance
        @param _token address of the token to approve.
        @param _spender spender
        @param _amount how much token will be provided to check allowance.
    */
    function approveTokenIfNeeded(
        address _token,
        address _spender,
        uint256 _amount
    ) public ownerExists(msg.sender) {
        if (IERC20(_token).allowance(address(this), address(_spender)) < _amount) {
            // safeApprove has special check
            IERC20(_token).safeApprove(address(_spender), 0);
            IERC20(_token).safeApprove(address(_spender), type(uint256).max);
        }
    }

    /**
        @dev Transfers rewards from autocompounder to position
        @param _token address of the reward token.
        @param _autocompounder address of autocompounder
        @param _amount reward amount.
    */
    function getRewardFromAutocompounder(
        address _token,
        address _autocompounder,
        uint256 _amount
    ) public ownerExists(msg.sender) {
        IERC20(_token).transferFrom(_autocompounder, address(this), _amount);
    }

    function withdrawFromAutocompounder(address _autocompounder, uint256 _amount) public {
        AutoCompounder ac = AutoCompounder(_autocompounder);
        ac.withdraw(address(this), _amount);
    }

    /**
        @dev Utility function to transfers tokens to receiver
        @param StandardTokenAddress token address to be transfered
        @param receiver address of tokens reveiver
        @param tokens amount to be transfered.
        @return success transfer result
    */
    function sendTokenAway(
        address StandardTokenAddress,
        address receiver,
        uint256 tokens
    ) internal returns (bool success) {
        ERC20Interface TokenContract = ERC20Interface(StandardTokenAddress);
        success = TokenContract.transfer(receiver, tokens);
        return success;
    }
}
