// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IERC20AccessControl.sol";

/*
* rewardsPerTokenStaked = ((stakingDuration * rewardRatioNumerator) / rewardRatioDenominator) / timeUnit
* 例如，如果奖励比率是 1/20，这意味着每质押 20 个代币将发放 1 个奖励代币，奖励比例的分子和分母应分别设置为1和20。
* stakingDuration ：质押持续时间（记录领取时间 - 质押时间---秒为单位）
* rewardRatioNumerator ：奖励比率分子
* rewardRatioDenominator ：奖励比率分母
* timeUnit ：生成奖励频率（秒为单位：1小时3600秒）
* 假设stakingDuration = 600秒（10分钟）、rewardRatioNumerator = 1、rewardRatioDenominator = 20、timeUnit = 60秒（1分钟）
* rewardsPerTokenStaked = 600 * 1 / 20 / 60 = 0.5个
*（领奖时不在下个60秒区间的奖励不计算在内）
*/
contract StakingPool is Ownable {

    using SafeMath for uint256;

    struct StakeInfo {
        // Eth
        uint256 balance;
        // LPEth
        uint256 rewards;
    }

    /* ========== STATE VARIABLES ========== */

    // LPEth address
    IERC20AccessControl public rewardsToken;

    // 用户本金（ETH）
    mapping(address => uint256) private _balances;
    // 用户奖励（LPEth）
    mapping(address => uint256) private _rewards;
    // 计算用户奖励的开始时间
    mapping(address => uint256) private _lastTime;


    // 奖励比率分子
    uint256 public rewardRatioNumerator = 1;
    // 奖励比率分母
    uint256 public rewardRatioDenominator = 20;
    // 生成奖励频率
    uint256 public timeUnit = 60;
    // 最少质押量
    uint256 public minStakeAmount = 0;


    /* ========== ADMIN function ========== */

    /*
    * 1. setRewardsToken: LPEth address
    */
    function init(address _rewardsToken) public onlyOwner {
        rewardsToken = IERC20AccessControl(_rewardsToken);
    }

    // setRewardRatio: 允许授权账户设置奖励比例
    function setRewardRatio(uint256 _rewardRatioNumerator, uint256 _rewardRatioDenominator) public onlyOwner {
        require(_rewardRatioDenominator != 0, "SetRewardRatio Error: rewardRatioDenominator is 0");

        emit UpdatedRewardRatio(rewardRatioNumerator, rewardRatioDenominator, _rewardRatioNumerator, _rewardRatioDenominator);
        rewardRatioNumerator = _rewardRatioNumerator;
        rewardRatioDenominator = _rewardRatioDenominator;
    }
    // setTimeUnit: 允许授权帐户将时间单位设置为秒数
    function setTimeUnit(uint256 _timeUnit) public onlyOwner {
        require(_timeUnit != 0, "SetTimeUnit Error: timeUnit is 0");

        emit UpdatedTimeUnit(timeUnit, _timeUnit);
        timeUnit = _timeUnit;
    }

    // setMinStakeAmount: 设置单次最小质押量
    function setMinStakeAmount(uint256 _minStakeAmount) public onlyOwner {
        require(_minStakeAmount != 0, "SetMinStakeAmount Error: minStakeAmount is 0");

        emit UpdatedMinStakeAmount(_minStakeAmount, minStakeAmount);
        minStakeAmount = _minStakeAmount;
    }

    /* ========== User function ========== */

    // getStakeInfo: 查看用户可获得的代币数量和总奖励
    function getStakeInfo(address account) public view returns (StakeInfo memory stakeInfo) {
        require(account != address(0), "GetStakeInfo Error: account is 0x0");

        stakeInfo.balance = _balances[account];
        stakeInfo.rewards = _rewards[account].add(calculateRewards(account));
    }
    // claimRewards: 获取累积奖励，这种领取方法允许采用拉式机制，用户必须发起奖励领取
    function claimRewards(address account) public updateReward(account) {
        require(account != address(0), "ClaimRewards Error: account is 0x0");

        uint256 rewardsAmount = _rewards[account];
        _rewards[account] = 0;
        rewardsToken.mint(account, rewardsAmount);

        emit RewardsClaimed(account, rewardsAmount);
    }
    // withdraw: 从合约中取消质押和提取代币
    function withdraw(address payable account) public updateReward(account) {
        require(account != address(0), "Withdraw Error: account is 0x0");

        uint256 ethAmount = _balances[account];
        _balances[account] = 0;
        account.transfer(ethAmount);

        emit TokensWithdrawn(account, ethAmount);
    }
    // stake: 用户通过传入数量来质押多少个代币 // msg.sender
    function stake(address from) public updateReward(from) payable {
        require(msg.value >= minStakeAmount, "Stake Error: msg.value < minStakeAmount");

        _balances[from] = _balances[from].add(msg.value);

        emit TokensStaked(from, msg.value);
    }

    // 查询用户已经质押的总量
    function stakedBalance(address account) public view returns (uint256) {
        require(account != address(0), "StakedBalance Error: account is 0x0");
        return _balances[account];
    }

    // 查询用户的奖励余额
    function rewardsBalance(address account) public view returns (uint256) {
        require(account != address(0), "RewardsBalance Error: account is 0x0");
        return _rewards[account].add(calculateRewards(account));
    }
    /*
    * 计算奖励
    * 1. 更新奖励时
    * 2. 查询奖励时
    */
    function calculateRewards(address account) private view returns (uint256) {
        if (_lastTime[account] == 0) {
            return 0;
        }
        uint256 stakingDuration = block.timestamp - _lastTime[account];
        uint256 rewardsPerTokenStaked = stakingDuration
        .div(timeUnit) // 保证不足timeUnit的部分不计算奖励
        .mul(rewardRatioNumerator)
        .mul(1e18) // 即保证计算精度又保证计算的结果符合rewardsToken的精度
        .div(rewardRatioDenominator);
        // 按照质押总量计算出奖励
        return rewardsPerTokenStaked.mul(_balances[account]).div(1e18);
    }

    /* ========== MODIFIERS ========== */

    /*
    * 按照时间和质押量更新奖励
    * 更新时机：stake、withdraw、claimRewards
    * 指导思想：a. 用户质押总量发送变化时(stake：总量变多、withdraw：总量减少)，需要更新奖励；
    *         b. 用户提取奖励时，需要更新后再提取；
    */
    modifier updateReward(address account) {
        // 计算出奖励
        uint256 rewards = calculateRewards(account);
        emit UpdateReward(account, _rewards[account], _rewards[account].add(rewards));
        // 更新用户奖励
        _rewards[account] = _rewards[account].add(rewards);
        // 更新下次计算奖励的开始时间为当前时间
        _lastTime[account] = block.timestamp;
        _;
    }

    /* ========== EVENTS ========== */

    event TokensStaked(address from, uint256 amount);
    event TokensWithdrawn(address user, uint256 ethAmount);
    event RewardsClaimed(address user, uint256 amount);
    event UpdatedTimeUnit(uint256 preTimeUnit, uint256 postTimeUnit);
    event UpdatedRewardRatio(uint256 preRewardRatioNumerator, uint256 preRewardRatioDenominator, uint256 postRewardRatioNumerator, uint256 postRewardRatioDenominator);
    event UpdatedMinStakeAmount(uint256 preMinStakeAmount, uint256 postMinStakeAmount);
    event UpdateReward(address account, uint256 preRewards, uint256 postRewards);

    // fallback
    receive() external payable {
        stake(msg.sender);
    }
    fallback() external payable {
        stake(msg.sender);
    }

}