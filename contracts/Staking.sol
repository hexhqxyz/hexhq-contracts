// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

error AmountMustBeGreaterThanZero();
error AmountNotEnough();
error TransferFailed();

contract Staking is ReentrancyGuard, Ownable, Pausable {
    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    uint256 public rewardRate;
    uint256 private totalStakedTokens;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    event Staked(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);
    event RewardsClaimed(address indexed user, uint256 indexed amount);
    event RewardRateUpdated(uint256 newRewardRate);
    event EmergencyWithdrawal(address indexed user, uint256 indexed amount);

    constructor(address stakingToken, address rewardToken) Ownable(msg.sender) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
        rewardRate = 1e15; // Initial reward rate
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStakedTokens == 0) {
            return rewardPerTokenStored;
        }
        uint256 totalTime = block.timestamp - lastUpdateTime;
        uint256 totalRewards = rewardRate * totalTime;
        return
            rewardPerTokenStored + ((totalRewards * 1e18) / totalStakedTokens);
    }

    function earned(address account) public view returns (uint256) {
        return
            ((stakedBalance[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    function stake(
        uint256 amount
    ) external nonReentrant whenNotPaused updateReward(msg.sender) {
        if (amount <= 0) revert AmountMustBeGreaterThanZero();
        totalStakedTokens += amount;
        stakedBalance[msg.sender] += amount;
        emit Staked(msg.sender, amount);
        bool success = s_stakingToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert TransferFailed();
    }

    function withdrawStakedTokens(
        uint256 amount
    ) external nonReentrant whenNotPaused updateReward(msg.sender) {
        if (amount <= 0) revert AmountMustBeGreaterThanZero();
        if (stakedBalance[msg.sender] < amount) revert AmountNotEnough();
        totalStakedTokens -= amount;
        stakedBalance[msg.sender] -= amount;
        emit Withdrawn(msg.sender, amount);
        bool success = s_stakingToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function getReward()
        external
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        uint256 reward = rewards[msg.sender];
        if (reward < 0) revert AmountNotEnough();

        rewards[msg.sender] = 0;
        emit RewardsClaimed(msg.sender, reward);
        bool success = s_rewardToken.transfer(msg.sender, reward);
        if (!success) revert TransferFailed();
    }

    function emergencyWithdraw() external nonReentrant whenPaused {
        uint256 amount = stakedBalance[msg.sender];
        if (amount <= 0) revert AmountMustBeGreaterThanZero();
        totalStakedTokens -= amount;
        stakedBalance[msg.sender] = 0;
        emit EmergencyWithdrawal(msg.sender, amount);
        bool success = s_stakingToken.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Additional functions to retrieve information for the frontend
    function totalStaked() external view returns (uint256) {
        return totalStakedTokens;
    }

    function stakedBalanceOf(address account) external view returns (uint256) {
        return stakedBalance[account];
    }

    function rewardBalanceOf(address account) external view returns (uint256) {
        return rewards[account];
    }
}
