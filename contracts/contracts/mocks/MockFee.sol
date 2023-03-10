// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockFee is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Returns the auto compound fee
    /// @return The number of reward token
    function getFee(uint256) external pure returns (uint256) {
        return 1e18;
    }

    /// @notice Owner collect the reward token
    /// @param _receiver receiver
    /// @param _token reward token
    function collectFee(address _receiver, address _token) external onlyOwner {
        IERC20(_token).safeTransfer(_receiver, IERC20(_token).balanceOf(address(this)));
    }
}
