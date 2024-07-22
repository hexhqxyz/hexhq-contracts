// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "hardhat/console.sol";

contract RewardToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("OmniDefi: Staking Rewards", "dUSD") {
        _mint(msg.sender, initialSupply*10**18);
    }
}