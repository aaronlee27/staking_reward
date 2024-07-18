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
    uint256 public constant INITIAL_AMOUNT = 100000 ether;

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

    function isEqual(uint x, uint y) public pure returns (bool){
        return abs(int(x) - int(y)) < ERROR_PRECISION;
    }

    function abs(int x) public pure returns (uint256) {
        if (x < 0){
            return uint256(-x);
        } else {
            return uint256(x);
        }
    }

    function testDeposit(uint256 _amountToStake, uint256 _blockToStake) external {
        _amountToStake = bound(_amountToStake, 1, INITIAL_AMOUNT);
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


    function testDepositBeforeRewardAndGetReward(uint256 _blockToStake, uint256 _amountToStake, uint256 _blockToUnstake) external {
        _blockToStake = bound(_blockToStake, 1, START_REWARD_BLOCK - 1);
        _amountToStake = bound(_amountToStake, 1, INITIAL_AMOUNT);
        stake(alice, _amountToStake, _blockToStake);

        _blockToUnstake = bound(_blockToUnstake, START_REWARD_BLOCK, START_REWARD_BLOCK + 1000);
        uint256 _expectedReward = (_blockToUnstake - START_REWARD_BLOCK) * REWARD_PER_BLOCK;
        vm.roll(_blockToUnstake);

        vm.startPrank(alice);

        staking.getReward();
        
        vm.stopPrank();

        console.log("Expected reward: ", _expectedReward);
        console.log("Alice's reward:  ", rewardToken.balanceOf(alice));

        assert(isEqual(rewardToken.balanceOf(alice), _expectedReward));
    }

    function testDepositAfterRewardAndGetReward(uint256 _blockToStake, uint256 _amountToStake, uint256 _blockToUnstake) external {
        _blockToStake = bound(_blockToStake, START_REWARD_BLOCK, START_REWARD_BLOCK + 1000);
        _amountToStake = bound(_amountToStake, 1, INITIAL_AMOUNT);

        stake(alice, _amountToStake, _blockToStake);

        _blockToUnstake = bound(_blockToUnstake, _blockToStake + 1, START_REWARD_BLOCK + 2000);
        uint256 _expectedReward = (_blockToUnstake - _blockToStake) * REWARD_PER_BLOCK;
        vm.roll(_blockToUnstake);

        vm.startPrank(alice);

        staking.getReward();
        
        vm.stopPrank();

        console.log("Expected reward: ", _expectedReward);
        console.log("Alice's reward:  ", rewardToken.balanceOf(alice));

        assert(isEqual(rewardToken.balanceOf(alice), _expectedReward));
    
    }


    function testDepositBeforeRewardAndGetRewardBeforeStartBlockReward(uint256 _blockToStake, uint256 _amountToStake, uint256 _blockToUnstake) public {
        _blockToStake = bound(_blockToStake, 1, START_REWARD_BLOCK - 2);
        _amountToStake = bound(_amountToStake, 1, INITIAL_AMOUNT);

        stake(alice, _amountToStake, _blockToStake);

        _blockToUnstake = bound(_blockToUnstake, _blockToStake + 1, START_REWARD_BLOCK - 1);
        uint256 _expectedReward = 0;
        vm.roll(_blockToUnstake);

        vm.startPrank(alice);

        staking.getReward();
        
        vm.stopPrank();

        console.log("Expected reward: ", _expectedReward);
        console.log("Alice's reward:  ", rewardToken.balanceOf(alice));

        assert(isEqual(rewardToken.balanceOf(alice), _expectedReward));
    }

    function testMultipleDepositAndGetReward(
        uint256 _aliceAmountToStake,
        uint256 _aliceBlockToStake,
        uint256 _bobAmountToStake,
        uint256 _bobBlockToStake,
        uint256 _aliceBlockToGetReward,
        uint256 _bobBlockToGetReward
    ) external {
        _aliceBlockToStake = bound(_aliceBlockToStake, START_REWARD_BLOCK + 1, START_REWARD_BLOCK + 1000);
        _aliceAmountToStake = bound(_aliceAmountToStake, 1, INITIAL_AMOUNT);

        _bobBlockToStake = bound(_bobAmountToStake, _aliceBlockToStake + 1, START_REWARD_BLOCK + 2000);
        _bobAmountToStake = bound(_bobAmountToStake, 1, INITIAL_AMOUNT);
        uint256 _totalAmount = _aliceAmountToStake + _bobAmountToStake;

        stake(alice, _aliceAmountToStake, _aliceBlockToStake);
        stake(bob, _bobAmountToStake, _bobBlockToStake);

        _aliceBlockToGetReward = bound(_aliceBlockToGetReward, _bobBlockToStake + 1, START_REWARD_BLOCK + 3000);
        _bobBlockToGetReward = bound(_bobBlockToGetReward, _aliceBlockToGetReward + 1, START_REWARD_BLOCK + 4000);

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

    function testMultipleDepositBeforeStartBlockRewardAndGetReward(
        uint256 _aliceAmountToStake,
        uint256 _aliceBlockToStake,
        uint256 _bobAmountToStake,
        uint256 _bobBlockToStake,
        uint256 _aliceBlockToGetReward,
        uint256 _bobBlockToGetReward
    ) external {
        _aliceBlockToStake = bound(_aliceBlockToStake, 1, START_REWARD_BLOCK - 2);
        _aliceAmountToStake = bound(_aliceAmountToStake, 1, INITIAL_AMOUNT);

        _bobBlockToStake = bound(_bobAmountToStake, _aliceBlockToStake + 1, START_REWARD_BLOCK - 1);
        _bobAmountToStake = bound(_bobAmountToStake, 1, INITIAL_AMOUNT);
        uint256 _totalAmount = _aliceAmountToStake + _bobAmountToStake;

        stake(alice, _aliceAmountToStake, _aliceBlockToStake);
        stake(bob, _bobAmountToStake, _bobBlockToStake);

        _aliceBlockToGetReward = bound(_aliceBlockToGetReward, START_REWARD_BLOCK + 1, START_REWARD_BLOCK + 3000);
        _bobBlockToGetReward = bound(_bobBlockToGetReward, _aliceBlockToGetReward + 1, START_REWARD_BLOCK + 4000);

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

    function testWithdraw(uint256 _amountToStake, uint256 _amountToUnstake) external {
        uint256 _blockToStake = START_REWARD_BLOCK + 10;
        _amountToStake = bound(_amountToStake, 1, INITIAL_AMOUNT);

        stake(alice, _amountToStake, _blockToStake);

        uint256 _blockToUnstake = START_REWARD_BLOCK + 150000;
         _amountToUnstake = _bound(_amountToUnstake, 1, _amountToStake);

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

        assert(isEqual(staking.stakerEarned(alice), _aliceExpectedRewards));  
    }

    function testCantWithDrawWithInsufficentDeposit(uint256 _amountToStake, uint256 _amountToUnstake) external {
        uint256 _blockToStake = START_REWARD_BLOCK + 10;
         _amountToStake = bound(_amountToStake, 1, INITIAL_AMOUNT);

        stake(alice, _amountToStake, _blockToStake);

        uint256 _blockToUnstake = START_REWARD_BLOCK + 150000;
         _amountToUnstake = bound(_amountToUnstake, _amountToStake + 1, _amountToStake + 1000);

        vm.roll(_blockToUnstake);
        
        vm.startPrank(alice);

        vm.expectRevert();
        staking.withdraw(_amountToUnstake);

        vm.stopPrank();
    }
}