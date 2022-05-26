// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardDistributor is Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public total;
    uint256 public sum;
    mapping(address => uint256) public presum;
    mapping(address => uint256) public staked;

    IERC20 public token;

    event STAKED(address staker, uint256 amount);
    event UNSTAKED(address unstaker, uint256 amount);
    event DISTRIBUTED(uint256 block, uint256 amount);

    constructor(address token_) {
        token = IERC20(token_);
    }

    function stake(uint256 _amount) public nonReentrant {
        token.transferFrom(msg.sender, address(this), _amount);
        staked[msg.sender] = _amount;
        presum[msg.sender] = sum;
        total += _amount;

        emit STAKED(msg.sender, _amount);
    }

    function unstakeAll() public nonReentrant {
        uint256 deposited = staked[msg.sender];

        uint256 amountUnstake = canStakeByUser(msg.sender);
        token.transfer(msg.sender, amountUnstake);
        // update data
        total -= deposited;
        staked[msg.sender] = 0;

        emit UNSTAKED(msg.sender, amountUnstake);
    }

    function unstake(uint256 _amount) public nonReentrant {
        uint256 amountUnstake = canStakeByUserAmount(msg.sender, _amount);
        token.transfer(msg.sender, amountUnstake);
        // update data
        total -= _amount;
        staked[msg.sender] -= _amount;
        presum[msg.sender] = sum;

        emit UNSTAKED(msg.sender, amountUnstake);
    }

    function distribute(uint256 _reward) public onlyOwner {
        require(total != 0, "distribute: No deposit");
        sum += (_reward * (1 ether)) / total;
        emit DISTRIBUTED(block.number, _reward);
    }

    function canStake() public view returns (uint256) {
        uint256 reward = (staked[msg.sender] * (sum - presum[msg.sender])) /
            1 ether;
        return staked[msg.sender] + reward;
    }

    function canStakeByUser(address _account) public view returns (uint256) {
        uint256 reward = (staked[_account] * (sum - presum[msg.sender])) /
            1 ether;
        return staked[_account] + reward;
    }

    function canStakeByUserAmount(address _account, uint256 _amount)
        public
        view
        returns (uint256)
    {
        uint256 reward = (_amount * (sum - presum[_account])) / 1 ether;
        return _amount + reward;
    }
}
