// SPDX-License-Identifer: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { ERC20A } from "../src/ERC20A.sol";
import { ERC20B } from "../src/ERC20B.sol";
import { Staking } from "../src/Staking.sol";

contract DeployStaking is Script {
    uint256 public constant START_FROM = 100;
    uint256 public constant REWARD_PER_BLOCK = 40;

    function run() external{
        vm.startBroadcast();

        // Deploy ERC20A
        ERC20A stakingToken = new ERC20A("Kyber Network Crystal", "KNC");
        ERC20B rewardToken = new ERC20B("Kyber Network Reward", "KNR");

        // Deploy Staking
        Staking staking = new Staking(address(stakingToken), address(rewardToken), REWARD_PER_BLOCK, START_FROM);

        rewardToken.transferOwnership(address(staking));

        vm.stopBroadcast();
    }   
}