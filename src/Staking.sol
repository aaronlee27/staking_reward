// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20, IERC20Reward } from "./interface/IERC20.sol";
import { IStaking } from "./interface/IStaking.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract Staking is IStaking, Ownable, Pausable {
    error StakingMustBeGreaterThanZero(address _staker);
    error WithdrawMustBeGreaterThanZero(address _staker);

    IERC20 private stakingToken;
    IERC20Reward private rewardToken;

    struct StakerInfo {
        uint256 amount;
        uint256 rewards;
        uint256 rewardDebt;
    }

    mapping(address => StakerInfo) private stakers;

    uint256 public constant PRECISION = 1e18;

    uint256 private totalStaked;
    uint256 private rewardPerBlock;
    uint256 private lastRewardedBlock;
    uint256 private accumulatedRewardsPerShare;
    uint256 private startRewardBlock;

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardPerBlock, uint256 _startRewardBlock) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20Reward(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        startRewardBlock = _startRewardBlock;
    }

    function deposit(uint256 _amount) public {
        if (_amount == 0){
            revert StakingMustBeGreaterThanZero(msg.sender);
        }
        updateReward(msg.sender);

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        totalStaked += _amount;

        StakerInfo storage staker = stakers[msg.sender];
        staker.amount += _amount;

    }   

    function withdraw(uint256 _amount) public {
        if (_amount == 0){
            revert WithdrawMustBeGreaterThanZero(msg.sender);
        }

        updateReward(msg.sender);
        
        stakingToken.transfer(msg.sender, _amount);
        totalStaked -= _amount;

        StakerInfo storage staker = stakers[msg.sender];
        staker.amount -= _amount;
    }

    function getReward() public {
        if (block.number < startRewardBlock) {
            return;
        }

        updateReward(msg.sender);
        
        StakerInfo storage staker = stakers[msg.sender];
        uint256 _rewards = staker.rewards;
        
        if (_rewards > 0){
            staker.rewards = 0;
            rewardToken.mint(msg.sender, _rewards);
        }
    }
    

    /// @notice Update reward only when block.number has passed the start Block time
    function updateReward(address _account) internal {
        accumulatedRewardsPerShare = accumulatedRewardsPerShare + trailingRewards(); // 0

        if (block.number < startRewardBlock) lastRewardedBlock = startRewardBlock;
        else lastRewardedBlock = block.number;

        StakerInfo storage staker = stakers[_account];
        staker.rewards = stakerEarned(_account);
        staker.rewardDebt = accumulatedRewardsPerShare;
    }

    function tokenRewardChangeOwnership(address _newOwner) public {
        rewardToken.transferOwnership(_newOwner);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function trailingRewards() public view returns (uint256){
        if (totalStaked == 0 || block.number < startRewardBlock) return 0;
        return rewardPerBlock * (block.number - lastRewardedBlock) * PRECISION / totalStaked;

    }

    function stakerEarned(address _account) public view returns (uint256) {
        StakerInfo memory staker = stakers[_account];
        return staker.rewards + staker.amount * (accumulatedRewardsPerShare - staker.rewardDebt) / PRECISION;
    }

    function isPaused() public view returns (bool){
        return paused();
    }

    function getStakingToken() public view returns (IERC20){
        return stakingToken;
    }

    function getRewardToken() public view returns (IERC20Reward){
        return rewardToken;
    }

    function getTotalStaked() public view returns (uint256){
        return totalStaked;
    }

    function getRewardPerBlock() public view returns (uint256){
        return rewardPerBlock;
    }

    function getStartRewardBlock() public view returns (uint256){
        return startRewardBlock;
    }

    function getStakerInfo(address _staker) public view returns (StakerInfo memory){
        return stakers[_staker];
    }

    function getStakerAmountStaked(address _staker) public view returns (uint256){
        return stakers[_staker].amount;
    }

    function getAccumulatedRewardsPerShare() public view returns (uint256){
        return accumulatedRewardsPerShare;
    }

    function getLastRewardedBlock() public view returns (uint256){
        return lastRewardedBlock;
    }
}