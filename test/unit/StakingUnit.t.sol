// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Staking } from "../../src/Staking.sol";
import { IERC20, IERC20Reward } from "../../src/interface/IERC20.sol";
import { ERC20A } from "../../src/ERC20A.sol";
import { ERC20B } from "../../src/ERC20B.sol";
import { Test, console } from "forge-std/Test.sol";

contract testStakingUnit is Test {
    Staking staking;
    ERC20A stakingToken;
    ERC20B rewardToken;

    uint256 public constant START_REWARD_BLOCK = 7;
    uint256 public constant REWARD_PER_BLOCK = 40 ether;
    uint256 public constant ERROR_PRECISION = 1e9; // 10^-9
    uint256 public constant INITIAL_AMOUNT = 100 ether;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() external {
        stakingToken = new ERC20A("Kyber Network Crystal", "KNC");
        rewardToken = new ERC20B("Kyber Network Reward", "KNR");
        staking = new Staking(address(stakingToken), address(rewardToken), REWARD_PER_BLOCK, START_REWARD_BLOCK);

        rewardToken.transferOwnership(address(staking));

        stakingToken.transfer(alice, INITIAL_AMOUNT);
        stakingToken.transfer(bob, INITIAL_AMOUNT);

    }

    function fund(address _account, uint256 _amount) public {
        stakingToken.transfer(_account, _amount);
    }

    function stake(address _account, uint256 _amount, uint256 _blockNumber) public {
        vm.startPrank(_account);
        
        vm.roll(_blockNumber);
        stakingToken.approve(address(staking), _amount);
        staking.deposit(_amount);

        vm.stopPrank();
    }
    function abs(int x) public pure returns (uint256) {
        if (x < 0){
            return uint256(-x);
        } else {
            return uint256(x);
        }
    }

    function testDeposit() external {
        uint256 _blockToStake = START_REWARD_BLOCK + 10;
        uint256 _amountToStake = 50 ether;
        stake(alice, _amountToStake, _blockToStake);
        // What to check???
        // Check if the staker has the correct amount of staking token
        // Check balance of the staking contract
        // Check the total staked amount   
        // check staker info
        assert(stakingToken.balanceOf(address(alice)) == INITIAL_AMOUNT - _amountToStake);
        assert(stakingToken.balanceOf(address(staking)) == _amountToStake);
        assert(staking.getTotalStaked() == _amountToStake);
        assert(staking.getStakerInfo(alice).amount == _amountToStake);
    }

    function testCantDepositWithZero() external {
        uint256 _blockToStake = START_REWARD_BLOCK + 10;
        uint256 _amountToStake = 0 ether;

        vm.roll(_blockToStake);
        vm.startPrank(alice);
        
        stakingToken.approve(address(staking), _amountToStake);

        vm.expectRevert(abi.encodeWithSelector(
            Staking.StakingMustBeGreaterThanZero.selector,
            alice
        ));
        staking.deposit(_amountToStake);

        vm.stopPrank();
        

        vm.stopPrank();
    }

    function testDepositBeforeRewardAndGetReward() external {
        uint256 _blockToStake = START_REWARD_BLOCK - 1;
        uint256 _amountToStake = 50 ether;
        stake(alice, _amountToStake, _blockToStake);

        uint256 _blockToUnstake = START_REWARD_BLOCK + 3;
        uint256 _expectedReward = (_blockToUnstake - START_REWARD_BLOCK) * REWARD_PER_BLOCK;
        vm.roll(_blockToUnstake);

        vm.startPrank(alice);

        staking.getReward();
        
        vm.stopPrank();

        console.log("Expected reward: ", _expectedReward);
        console.log("Alice's reward:  ", rewardToken.balanceOf(alice));

        assert(rewardToken.balanceOf(alice) == _expectedReward);
    }

    function testDepositAfterRewardAndGetReward() external {
        uint256 _blockToStake = START_REWARD_BLOCK + 3;
        uint256 _amountToStake = 50 ether;

        stake(alice, _amountToStake, _blockToStake);

        uint256 _blockToUnstake = 15;
        uint256 _expectedReward = (_blockToUnstake - 10) * REWARD_PER_BLOCK;
        vm.roll(_blockToUnstake);

        vm.startPrank(alice);

        staking.getReward();
        
        vm.stopPrank();

        console.log("Expected reward: ", _expectedReward);
        console.log("Alice's reward:  ", rewardToken.balanceOf(alice));

        assert(rewardToken.balanceOf(alice) == _expectedReward);
    
    }

    function testMultipleDepositAndGetReward() external {
        uint256 _aliceBlockToStake = 9;
        uint256 _aliceAmountToStake = 87 ether;

        uint256 _bobBlockToStake = 19;
        uint256 _bobAmountToStake = 92 ether;
        uint256 _totalAmount = _aliceAmountToStake + _bobAmountToStake;

        stake(alice, _aliceAmountToStake, _aliceBlockToStake);
        stake(bob, _bobAmountToStake, _bobBlockToStake);

        uint256 _aliceBlockToGetReward = 23;
        uint256 _bobBlockToGetReward = 47;

        uint256 _aliceExpectedReward = (_bobBlockToStake - _aliceBlockToStake) * REWARD_PER_BLOCK + (_aliceBlockToGetReward - _bobBlockToStake) * REWARD_PER_BLOCK * (_aliceAmountToStake) / _totalAmount;
        uint256 _bobExpectedReward = (_bobBlockToGetReward - _bobBlockToStake) * REWARD_PER_BLOCK * (_bobAmountToStake) / _totalAmount;

        vm.roll(_aliceBlockToGetReward);
        vm.startPrank(alice);
        
        staking.getReward();

        vm.stopPrank();


        vm.roll(_bobBlockToGetReward);
        vm.startPrank(bob);

        staking.getReward();

        vm.stopPrank();

        console.log("Alice's expected reward: ", _aliceExpectedReward);
        console.log("Alice's reward:  ", rewardToken.balanceOf(alice));

        console.log("Bob's expected reward: ", _bobExpectedReward);
        console.log("Bob's reward:  ", rewardToken.balanceOf(bob));

        assert(abs(int(rewardToken.balanceOf(alice)) - int(_aliceExpectedReward)) < ERROR_PRECISION);
        assert(abs(int(rewardToken.balanceOf(bob)) - int(_bobExpectedReward)) < ERROR_PRECISION);
    }

    function testMultipleDepositBeforeStartBlockRewardAndGetReward() external {
        uint256 _aliceBlockToStake = 3;
        uint256 _aliceAmountToStake = 10 ether;

        uint256 _bobBlockToStake = 4;
        uint256 _bobAmountToStake = 20 ether;
        uint256 _totalAmount = _aliceAmountToStake + _bobAmountToStake;

        stake(alice, _aliceAmountToStake, _aliceBlockToStake);
        stake(bob, _bobAmountToStake, _bobBlockToStake);

        uint256 _aliceBlockToGetReward = 23;
        uint256 _bobBlockToGetReward = 47;

        uint256 _aliceExpectedReward = REWARD_PER_BLOCK * (_aliceBlockToGetReward - START_REWARD_BLOCK) * _aliceAmountToStake / _totalAmount;
        uint256 _bobExpectedReward = REWARD_PER_BLOCK * (_bobBlockToGetReward - START_REWARD_BLOCK) * _bobAmountToStake / _totalAmount;

        vm.roll(_aliceBlockToGetReward);
        vm.startPrank(alice);
        
        staking.getReward();

        vm.stopPrank();


        vm.roll(_bobBlockToGetReward);
        vm.startPrank(bob);

        staking.getReward();

        vm.stopPrank();

        console.log("Alice's expected reward: ", _aliceExpectedReward);
        console.log("Alice's reward:  ", rewardToken.balanceOf(alice));

        console.log("Bob's expected reward: ", _bobExpectedReward);
        console.log("Bob's reward:  ", rewardToken.balanceOf(bob));

        assert(abs(int(rewardToken.balanceOf(alice)) - int(_aliceExpectedReward)) < ERROR_PRECISION);
        assert(abs(int(rewardToken.balanceOf(bob)) - int(_bobExpectedReward)) < ERROR_PRECISION);
    }

    function testWithdraw() external {
        uint256 _blockToStake = START_REWARD_BLOCK + 10;
        uint256 _amountToStake = 50 ether;

        stake(alice, _amountToStake, _blockToStake);

        uint256 _blockToUnstake = START_REWARD_BLOCK + 150000;
        uint256 _amountToUnstake = 30 ether;

        vm.roll(_blockToUnstake);
        
        vm.startPrank(alice);

        staking.withdraw(_amountToUnstake);

        vm.stopPrank();

        // What to check
        // balance of the staking contract
        // balance of the staker
        // total staked amount
        // get reward

        assert(stakingToken.balanceOf(address(alice)) == INITIAL_AMOUNT - _amountToStake + _amountToUnstake);
        assert(stakingToken.balanceOf(address(staking)) == _amountToStake - _amountToUnstake);
        assert(staking.getTotalStaked() == _amountToStake - _amountToUnstake);
        assert(staking.getStakerInfo(alice).amount == _amountToStake - _amountToUnstake);
        
        uint256 _aliceExpectedRewards = (_blockToUnstake - _blockToStake) * REWARD_PER_BLOCK;
        console.log("Alice's expected reward: ", _aliceExpectedRewards);
        console.log("Alice's reward:  ", staking.stakerEarned(alice));

        assert(staking.stakerEarned(alice) == _aliceExpectedRewards);  
    }

    function testCantWithDrawWithInsufficentDeposit() external {
        uint256 _blockToStake = START_REWARD_BLOCK + 10;
        uint256 _amountToStake = 50 ether;

        stake(alice, _amountToStake, _blockToStake);

        uint256 _blockToUnstake = START_REWARD_BLOCK + 150000;
        uint256 _amountToUnstake = 100 ether;

        vm.roll(_blockToUnstake);
        
        vm.startPrank(alice);

        vm.expectRevert();
        staking.withdraw(_amountToUnstake);

        vm.stopPrank();
    }

    function testCantWithDrawWithZero() external {
        uint256 _blockToStake = START_REWARD_BLOCK + 10;
        uint256 _amountToStake = 50 ether;

        stake(alice, _amountToStake, _blockToStake);

        uint256 _blockToUnstake = START_REWARD_BLOCK + 150000;
        uint256 _amountToUnstake = 0 ether;

        vm.roll(_blockToUnstake);
        
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(
            Staking.WithdrawMustBeGreaterThanZero.selector,
            alice
        ));
        staking.withdraw(_amountToUnstake);

        vm.stopPrank();
    }

    function testGetReward() external {

    }

    function testChangeOwnershipToken() external {

    }

    
}