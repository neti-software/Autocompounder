// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libs/UnstructuredStorage.sol";

/**
 * @title Interest-bearing ERC20-like token for Lido Liquid Stacking protocol.
 * @dev  * This contract is abstract. To make the contract deployable override the
 * `_getTotalPooledALP` function. `Lido.sol` contract inherits StETH and defines
 * the `_getTotalPooledALP` function.
 *
 * StETH balances are dynamic and represent the holder's share in the total amount
 * of Ether controlled by the protocol. Account _shares aren't normalized, so the
 * contract also stores the sum of all _shares to calculate each account's token balance
 * which equals to:
 *
 *   _shares[account] * _getTotalPooledALP() / _getTotalShares()
 *
 * For example, assume that we have:
 *
 *   _getTotalPooledALP() -> 10 ETH
 *   _sharesOf(user1) -> 100
 *   _sharesOf(user2) -> 400
 *
 * Therefore:
 *
 *   balanceOf(user1) -> 2 tokens which corresponds 2 ETH
 *   balanceOf(user2) -> 8 tokens which corresponds 8 ETH
 *
 * Since balances of all token holders change when the amount of total pooled Ether
 * changes, this token cannot fully implement ERC20 standard: it only emits `Transfer`
 * events upon explicit transfer between holders. In contrast, when total amount of
 * pooled Ether increases, no `Transfer` events are generated: doing so would require
 * emitting an event for each token holder and thus running an unbounded loop.
 *
 * The token inherits from `Pausable` and uses `whenNotStopped` modifier for methods
 * which change `_shares` or `_allowances`. `_stop` and `_resume` functions are overriden
 * in `Lido.sol` and might be called by an account with the `PAUSE_ROLE` assigned by the
 * DAO. This is useful for emergency scenarios, e.g. a protocol bug, where one might want
 * to freeze all token transfers and approvals until the emergency is resolved.
 */
abstract contract AutocompounderERC20 is IERC20 {
    using UnstructuredStorage for bytes32;

    /**
     * @dev StETH balances are dynamic and are calculated based on the accounts' _shares
     * and the total amount of Ether controlled by the protocol. Account _shares aren't
     * normalized, so the contract also stores the sum of all _shares to calculate
     * each account's token balance which equals to:
     *
     *   _shares[account] * _getTotalPooledALP() / _getTotalShares()
     */
    mapping(address => uint256) private _shares;

    /**
     * @dev Allowances are nominated in tokens, not token _shares.
     */
    mapping(address => mapping(address => uint256)) private _allowances;

    /**
     * @dev Storage position used for holding the total amount of _shares in existence.
     *
     * The Lido protocol is built on top of Aragon and uses the Unstructured Storage pattern
     * for value types:
     *
     * https://blog.openzeppelin.com/upgradeability-using-unstructured-storage
     * https://blog.8bitzen.com/posts/20-02-2020-understanding-how-solidity-upgradeable-unstructured-proxies-work
     *
     * For reference types, conventional storage variables are used since it's non-trivial
     * and error-prone to implement reference-type unstructured storage using Solidity v0.4;
     * see https://github.com/lidofinance/lido-dao/issues/181#issuecomment-736098834
     */
    bytes32 internal constant _TOTAL_SHARES_POSITION = keccak256("Autocompounder");

    /**
     * @dev Return the amount of tokens in existence. Always equals to `_getTotalPooledALP()` since token amount
     * is pegged to the total amount of Ether controlled by the protocol.
     */
    function totalSupply() override public view returns (uint256) {
        return _getTotalPooledALP();
    }

    /**
     * @dev Return the amount of tokens owned by the `_account`.Balances are dynamic and equal the `_account`'s share in the amount of the
     * total Ether controlled by the protocol. See `_sharesOf`.
     * @param _account Address of account to chceck balance
     */
    function balanceOf(address _account) override public view returns (uint256) {
        return getPooledALPByShares(_sharesOf(_account));
    }

    /**
     * @dev Moves `_amount` tokens from the caller's account to the `_recipient` account.
     *
     * Return a boolean value indicating whether the operation succeeded.
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the caller must have a balance of at least `_amount`.
     * - the contract must not be paused.
     *
     * @param _amount Amount of tokens, not _shares.
     * @param _recipient Addres of tokens recipient
     */
    function transfer(address _recipient, uint256 _amount) override public returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    /**
     * @return the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     *
     * @dev This value changes when `approve` or `transferFrom` is called.
     * @param _owner Owner address
     * @param _spender Spender address
     */
    function allowance(address _owner, address _spender) override public view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @dev Sets `_amount` as the allowance of `_spender` over the caller's tokens.
     *
     * Return a boolean value indicating whether the operation succeeded.
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `_spender` cannot be the zero address.
     * - the contract must not be paused.
     *
     * @param _amount Amount of tokens, not _shares.
     * @param _spender Spender address
     */
    function approve(address _spender, uint256 _amount) override public returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @dev Moves `_amount` tokens from `_sender` to `_recipient` using the
     * allowance mechanism. `_amount` is then deducted from the caller's
     * allowance.
     *
     * Return a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_sender` and `_recipient` cannot be the zero addresses.
     * - `_sender` must have a balance of at least `_amount`.
     * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
     * - the contract must not be paused.
     *
     * @param _amount Amount of tokens, not _shares.
     * @param _sender Spender address
     * @param _recipient Addres of tokens recipient
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) override public returns (bool) {
        uint256 currentAllowance = _allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, currentAllowance - _amount);
        return true;
    }

    
    ///@dev The sum of all accounts' _shares can be an arbitrary number, therefore it is necessary to store it in order to calculate each account's relative share.
    ///@return the total amount of _shares in existence.
    function getTotalShares() public view returns (uint256) {
        return _getTotalShares();
    }

    /**
     * @dev Return the amount of _shares owned by `_account`.
     * @param _account Owner address
     */
    function sharesOf(address _account) public view returns (uint256) {
        return _sharesOf(_account);
    }

    /**
     * @dev Return the amount of _shares that corresponds to `_alpAmount` protocol-controlled Ether.
       @param _alpAmount ALP Amount 
     */
    function getSharesByPooledALP(uint256 _alpAmount) public view returns (uint256) {
        uint256 totalPooledEther = _getTotalPooledALP();
        if (totalPooledEther == 0) {
            return 0;
        } else {
            return (_alpAmount * _getTotalShares()) / totalPooledEther;
        }
    }

    /**
     * @dev Return the amount of Ether that corresponds to `_sharesAmount` token _shares.
     * @param _sharesAmount Tokens SharesAmount
     */
    function getPooledALPByShares(uint256 _sharesAmount) public view returns (uint256) {
        uint256 totalShares = _getTotalShares();
        if (totalShares == 0) {
            return 0;
        } else {
            return (_sharesAmount * _getTotalPooledALP()) / totalShares;
        }
    }

    /**
     * 
     * @dev This is used for calculating tokens from _shares and vice versa. This function is required to be implemented in a derived contract.
     * @return uint256 the total amount (in wei) of Ether controlled by the protocol.
     */
    function _getTotalPooledALP() internal view virtual returns (uint256);

    /**
     * @dev Moves `_amount` tokens from `_sender` to `_recipient`.
     * @param _sender Sender address
     * @param _recipient Recipient address
     * @param _amount ALP amount
     */
    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        uint256 _sharesToTransfer = getSharesByPooledALP(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);

        emit Transfer(_sender, _recipient, _amount);
    }

    /**
     * @dev Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
     * 
     * Emits an `Approval` event.
     *
     *  Requirements:
     *
     * - `_owner` cannot be the zero address.
     * - `_spender` cannot be the zero address.
     * - the contract must not be paused.
     * @param _owner Owner address
     * @param _spender Spender address
     * @param _amount Tokens amount
     */
    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @dev Returns the total amount of _shares in existence.
     */
    function _getTotalShares() public view returns (uint256) {
        return _TOTAL_SHARES_POSITION.getStorageUint256();
    }

    /**
     * @dev Returns the amount of _shares owned by `_account`.
     */
    function _sharesOf(address _account) internal view returns (uint256) {
        return _shares[_account];
    }

    /**
     * @dev Moves `_sharesAmount` _shares from `_sender` to `_recipient`.
     *  
     * Requirements:
     *
     * - `_sender` cannot be the zero address.
     * - `_recipient` cannot be the zero address.
     * - `_sender` must hold at least `_sharesAmount` _shares.
     * - the contract must not be paused.
     * @param _sharesAmount Amount of tokens
     * @param _sender Spender address
     * @param _recipient Addres of tokens recipient
     * 
     */
    function _transferShares(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");

        uint256 currentSenderShares = _shares[_sender];
        require(_sharesAmount <= currentSenderShares, "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        _shares[_sender] = currentSenderShares - _sharesAmount;
        _shares[_recipient] = _shares[_recipient] + _sharesAmount;
    }

    /**
     * @dev Creates `_sharesAmount` _shares and assigns them to `_recipient`, increasing the total amount of _shares.
     * This doesn't increase the token total supply.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the contract must not be paused.
     * @param _sharesAmount Amount of tokens
     * @param _recipient Addres of tokens recipient
     */
    function _mintShares(address _recipient, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
        require(_recipient != address(0), "MINT_TO_THE_ZERO_ADDRESS");

        newTotalShares = _getTotalShares() + _sharesAmount;
        _TOTAL_SHARES_POSITION.setStorageUint256(newTotalShares);

        _shares[_recipient] = _shares[_recipient] + _sharesAmount;

        // Notice: we're not emitting a Transfer event from the zero address here since _shares mint
        // works by taking the amount of tokens corresponding to the minted _shares from all other
        // token holders, proportionally to their share. The total supply of the token doesn't change
        // as the result. This is equivalent to performing a send from each other token holder's
        // address to `address`, but we cannot reflect this as it would require sending an unbounded
        // number of events.
    }

    /**
     * @dev Destroys `_sharesAmount` _shares from `_account`'s holdings, decreasing the total amount of _shares.
     * This doesn't decrease the token total asupply.
     *
     * Requirements:
     *
     * - `_account` cannot be the zero address.
     * - `_account` must hold at least `_sharesAmount` _shares.
     * - the contract must not be paused.
     * @param _sharesAmount Amount of tokens
     * @param _account Account address
     */
    function _burnShares(address _account, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
        require(_account != address(0), "BURN_FROM_THE_ZERO_ADDRESS");

        uint256 accountShares = _shares[_account];
        require(_sharesAmount <= accountShares, "BURN_AMOUNT_EXCEEDS_BALANCE");

        newTotalShares = _getTotalShares() - _sharesAmount;
        _TOTAL_SHARES_POSITION.setStorageUint256(newTotalShares);

        _shares[_account] = accountShares - _sharesAmount;

        // Notice: we're not emitting a Transfer event to the zero address here since _shares burn
        // works by redistributing the amount of tokens corresponding to the burned _shares between
        // all other token holders. The total supply of the token doesn't change as the result.
        // This is equivalent to performing a send from `address` to each other token holder address,
        // but we cannot reflect this as it would require sending an unbounded number of events.
    }
}
