// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("AstraDeFi: Staking Token", "ATX") {
        _mint(msg.sender, initialSupply*10**18);
    }
}
