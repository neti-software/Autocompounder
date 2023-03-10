// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

contract Const {
    uint256 public constant BONE = 10**40;

    uint8 public constant BASE_DECIMALS = 18;

    uint256 public constant MIN_BPOW_BASE = 1 wei;
    uint256 public constant MAX_BPOW_BASE = (2 * BONE) - 1 wei;
    uint256 public constant BPOW_PRECISION = BONE / 10**10;

    bytes32 public constant ADMIN = keccak256("ADMIN");

    uint8 public constant SINGLE_REWARD = 1;
    uint8 public constant DOUBLE_REWARD = 2;
    uint8 public constant TRIPLE_REWARD = 3;
}
