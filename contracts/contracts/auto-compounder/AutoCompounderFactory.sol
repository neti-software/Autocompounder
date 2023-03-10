// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./interfaces/IAutoCompounderFactory.sol";
import "./AutoCompounderDeployer.sol";
///@title Autocompounder factory contract
///@author NETI
///@dev Mint Autocompounder contracts and initiate it with fee settings, staking contract address, reward tokens addresses, farming pool type, and MultiSignatureContract reference
contract AutoCompounderFactory is IAutoCompounderFactory, AccessControl, AutoCompounderDeployer {
    // ADMIN role
    bytes32 public constant ADMIN = keccak256("ADMIN");
    address public pendingOwner;
    bool public pendingOwnerApproval;

    IUniswapV2Factory public override uniswapV2Factory;
    // list autocompounder address from farming pool address
    mapping(address => address) public getAutoCompounder;
    
    /* ========== MODIFIERS ========== */
    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner, "AC: NPO"); //NotPendingOwner
        _;
    }
    ///@dev Initialise MultiSignature reference
    ///@param multiSignAddress Multisig address
    constructor(address multiSignAddress) {
        _setRoleAdmin(ADMIN, ADMIN);
        _setupRole(ADMIN, multiSignAddress);
    }
    
    /// @dev nominate New Owner
    /// @param nominatedAddress New Owner address
    function nomiateOwner(address nominatedAddress) external {
        require(hasRole(ADMIN, msg.sender), "AC: AR");
        require(nominatedAddress!=msg.sender,"AC: SC"); // Self Call
        pendingOwner = nominatedAddress;
    }

    /// @dev Approve the ownership as new Owner
    function approveOwnership() onlyPendingOwner external {
        pendingOwnerApproval = true;
    }

    /// @dev Renounce ownership and transfer it to new pendingOwner
    function renounceAndTransferOwnership() external {
        require(hasRole(ADMIN, msg.sender), "AC: AR");
        require(pendingOwnerApproval,"AC: PONA"); // PendingOwnerNotApproved
        grantRole(ADMIN, pendingOwner);
        revokeRole(ADMIN, msg.sender);
        pendingOwner = address(0);
        pendingOwnerApproval = false;
    }

    /// @dev Set Uniswap v2 factory
    /// @param _addr Uniswap V2 factory address
    function setUniswapV2Factory(address _addr) external {
        require(hasRole(ADMIN, msg.sender), "AC: AR");

        uniswapV2Factory = IUniswapV2Factory(_addr);
    }

    
    /// @dev Create new autocompounder instance
    /// @param _feeContract Fee contract address
    /// @param _farmingPoolAddress Farming pool address
    /// @param _uniswapV2Router Uniswap router address
    /// @param _farmingPoolType Farming Pool Typ
    /// @param _firstRewardAddress First address for staking rewards
    /// @param _secondRewardAddress Second address for staking rewards
    /// @param _thirdRewardAddress Third address for staking rewards
    /// @return autoCompounder address
    function createAutoCompounder(
        address _feeContract,
        address _farmingPoolAddress,
        address _uniswapV2Router,
        uint8 _farmingPoolType,
        address _firstRewardAddress,
        address _secondRewardAddress,
        address _thirdRewardAddress
    ) external override returns (address autoCompounder) {
        require(hasRole(ADMIN, msg.sender), "AC: AR");

        if (getAutoCompounder[_farmingPoolAddress] != address(0)) {
            return getAutoCompounder[_farmingPoolAddress];
        }

        autoCompounder = _deploy(
            _feeContract,
            address(this),
            _farmingPoolAddress,
            _uniswapV2Router,
            _farmingPoolType,
            _firstRewardAddress,
            _secondRewardAddress,
            _thirdRewardAddress
        );

        getAutoCompounder[_farmingPoolAddress] = address(autoCompounder);

        emit AutoCompounderCreated(address(autoCompounder));
    }
}
