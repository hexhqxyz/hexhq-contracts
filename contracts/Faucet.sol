// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Faucet is Ownable {
    error FaucetAlreadyClaimed(address claimer);
    error FaucetInsufficientFunds(uint256 requested, uint256 available);
    error ClaimTooSoon(uint256 timeLeft);

    IERC20 public token;
    uint256 public amountAllowed;
    // mapping(address => bool) public hasClaimed;
    uint256 public claimInterval;
    mapping(address => uint256) public lastClaimed;

    event Claimed(address indexed user, uint256 amount);

    constructor(
        address _token,
        uint256 _amountAllowed,
        uint256 _claimInterval
    ) Ownable(msg.sender) {
        token = IERC20(_token);
        amountAllowed = _amountAllowed;
        claimInterval = _claimInterval; // set claim interval in seconds
    }

    function claimTokens() external {
        uint256 currentTime = block.timestamp;
        uint256 lastClaimedTime = lastClaimed[msg.sender];

        if (currentTime < lastClaimedTime + claimInterval) {
            revert ClaimTooSoon(lastClaimedTime + claimInterval - currentTime);
        }

        uint256 faucetBalance = token.balanceOf(address(this));
        if (faucetBalance < amountAllowed) {
            revert FaucetInsufficientFunds(amountAllowed, faucetBalance);
        }

        lastClaimed[msg.sender] = currentTime;
        token.transfer(msg.sender, amountAllowed);
        emit Claimed(msg.sender, amountAllowed);
    }

    function setAmountAllowed(uint256 _amountAllowed) external onlyOwner {
        amountAllowed = _amountAllowed;
    }

    function setClaimInterval(uint256 _claimInterval) external onlyOwner {
        claimInterval = _claimInterval;
    }

    function withdrawTokens(uint256 _amount) external onlyOwner {
        token.transfer(msg.sender, _amount);
    }
}
