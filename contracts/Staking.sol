// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Staking is ReentrancyGuard, Ownable, Pausable {
    error AmountMustBeGreaterThanZero();
    error AmountNotEnough();
    error TransferFailed();
    error LoanNotRepaid();
    error InsufficientCollateral();

    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    uint256 public rewardRate;
    uint256 public totalStakedTokens;
    uint256 public totalBorrowedAmount;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public interestRate; // Annual interest rate for loans

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public borrowedAmount;
    mapping(address => uint256) public loanStartTime;

    event Staked(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);
    event RewardsClaimed(address indexed user, uint256 indexed amount);
    event RewardRateUpdated(uint256 newRewardRate);
    event EmergencyWithdrawal(address indexed user, uint256 indexed amount);
    event LoanTaken(address indexed user, uint256 indexed amount);
    event LoanRepaid(address indexed user, uint256 indexed amount);

    constructor(address stakingToken, address rewardToken) Ownable(msg.sender) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
        rewardRate = 1e15; // Initial reward rate
        interestRate = 5; // 5% annual interest rate
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function setInterestRate(uint256 _interestRate) external onlyOwner {
        interestRate = _interestRate;
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
        uint256 effectiveStakedBalance = stakedBalance[account] -
            borrowedAmount[account];

        return
            ((effectiveStakedBalance *
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
        if (borrowedAmount[msg.sender] > 0) revert LoanNotRepaid(); // Prevent withdrawal if there's an outstanding loan

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
        if (borrowedAmount[msg.sender] > 0) revert LoanNotRepaid();

        uint256 reward = rewards[msg.sender];
        if (reward < 0) revert AmountNotEnough();

        rewards[msg.sender] = 0;
        emit RewardsClaimed(msg.sender, reward);
        bool success = s_rewardToken.transfer(msg.sender, reward);
        if (!success) revert TransferFailed();
    }

    function takeLoan(uint256 amount) external nonReentrant whenNotPaused {
        if (amount <= 0) revert AmountMustBeGreaterThanZero();
        if (borrowedAmount[msg.sender] > 0) revert LoanNotRepaid();
        if ((stakedBalance[msg.sender] * 80) / 100 < amount)
            revert InsufficientCollateral(); // Borrow up to 80% of staked amount

        borrowedAmount[msg.sender] += amount;
        loanStartTime[msg.sender] = block.timestamp;
        totalBorrowedAmount += amount;

        emit LoanTaken(msg.sender, amount);
        bool success = s_rewardToken.transfer(msg.sender, amount); // Use reward token for loans
        if (!success) revert TransferFailed();
    }

    function repayLoan(uint256 amount) external nonReentrant whenNotPaused {
        if (amount <= 0) revert AmountMustBeGreaterThanZero();
        if (borrowedAmount[msg.sender] < amount) revert AmountNotEnough();
        uint256 interest = calculateInterest(msg.sender);
        require(
            s_rewardToken.transferFrom(
                msg.sender,
                address(this),
                amount + interest
            ),
            "Transfer failed"
        );
        borrowedAmount[msg.sender] -= amount;
        totalBorrowedAmount -= amount;
        if (borrowedAmount[msg.sender] == 0) {
            loanStartTime[msg.sender] = 0;
        }
        emit LoanRepaid(msg.sender, amount);
    }

    function calculateInterest(address account) public view returns (uint256) {
        uint256 timeElapsed = ((block.timestamp - loanStartTime[account]) /
            20) * 20; // Round down to the nearest 20 seconds
        uint256 annualInterest = (borrowedAmount[account] * interestRate) / 100;
        uint256 interest = (annualInterest * timeElapsed) / 365 days;
        return interest;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function borrowedBalanceOf(
        address account
    ) external view returns (uint256) {
        return borrowedAmount[account];
    }

    function calculateBorrowLimit(
        address account
    ) external view returns (uint256) {
        if (borrowedAmount[msg.sender] > 0 || stakedBalance[account] <= 0)
            return 0; // if outstanding loan

        return (stakedBalance[account] * 80) / 100; // 80% of staked amount
    }

    function calculateRepayAmount(
        address account
    ) external view returns (uint256) {
        uint256 interest = calculateInterest(account);
        return borrowedAmount[account] + interest;
    }
}
