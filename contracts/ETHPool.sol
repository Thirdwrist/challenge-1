//SPDX-License-Identifier: Unlicense

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

pragma solidity ^0.8.0;

contract ETHPool{

    using SafeMath for uint256;

    /*
        *
        ***** Storage Variables  ******
        *
    */ 

    // The current reward session 
    uint currentReward;

    // The admin/contract owner 
    address admin;

    // The total balance of deposits from user address
    uint poolBalance;

    // The individual balances of users 
    mapping(address => uint) balances;

    // The last time a user made a change to it's stake
    mapping(address => uint) lastUpdates;

    // Index of all rewards by team
    Reward[] rewards;

    /*
        *
        ***** Structs ******
        *
    */ 

    // The reward struck for amount rewarded and pool balance at time of reward
    struct Reward {
        uint amount;
        uint poolBalance;
    }
    
    /*
        *
        ***** Events ******
        *
    */ 

    // Event emited when a deposit/stake is made by a user
    event Deposit(address indexed account, uint amount);

    // When a user widraws his stake from the contract. 
    event Withdraw(address indexed account, uint amount);

    // When a team member deposits a reward into the contract 
    event Rewarded(address indexed account, uint amount, uint index);

    // Emited when a user redeems it's reward for stake
    event Redeem(address account, uint amount);

    /*
        *
        ***** Modifiers ******
        *
     */ 

    // Redeem user rewards before function execution 
    modifier redeemReward() {
        _redeemReward();
        _;
    }

    // Allow calls only when value is staked
    modifier hasStake(){
        require(balances[msg.sender] > 0, 'Must have existing stake');
        _;
    }

    // Only contract owner can access
    modifier onlyOwner(){
        require(msg.sender == admin, 'must be owner');
        _;
    }

    constructor (){
        admin = msg.sender;
    }

    // User deposits stake in pool
    function depositStake() public redeemReward payable{
        require(msg.value > 0, 'Must deposit actual value');

        balances[msg.sender] += msg.value;
        poolBalance += msg.value;
        
        emit Deposit(msg.sender, msg.value);
    }

    // @notice Withdraw stake from pool
    // @dev The redeemReward modifier attempts to redeem due reward before function run
    // @dev The only responsibility of this function is to withdraw and change state, the redemption of rewards and state change...
    // @dev ...due to redemption is completely abstracted to the modifier.
    function withdrawStake() public  hasStake redeemReward  {

        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;
        poolBalance -= amount;

        (bool success, ) = msg.sender.call{value:amount}("");
        require(success, "Transfer failed.");
    }

    // @notice Redeems reward from all previous reward circles
    // @dev This moves all rewards to users balance and stakes it for next circle of rewards. 
    function redeem() hasStake public {
        require(lastUpdates[msg.sender] != currentReward, 'Stake has not matured yet');
        _redeemReward();
    }

    // @notice Private function to redeem rewards for user on all circles. 
    // @dev This moves all rewards to users balance and stakes it for next circle of rewards.
    function _redeemReward() private {

        uint _balance = balances[msg.sender];
        uint _lastUpdate = lastUpdates[msg.sender];

        if(_balance > 0 && _lastUpdate < currentReward)
        {
            uint _reward;
            for(uint i=_lastUpdate; i < currentReward; i++)
            {
                _reward += _balance.mul(rewards[i].amount).div(rewards[i].poolBalance);
            }
            balances[msg.sender] += _reward; 
            emit Redeem(msg.sender, _reward);

        }
        lastUpdates[msg.sender] = currentReward;
    }

    // @notice For team members to deposit reward into pool
    function depositePoolReward () public onlyOwner payable{

        require(poolBalance > 0, 'There is no stake to reward');
        require(msg.value > 0, 'Must send value');

        Reward memory _reward;
        _reward.amount = msg.value;
        _reward.poolBalance = poolBalance;

        rewards.push(_reward);

        ++currentReward;
        poolBalance += msg.value;
        emit Rewarded(msg.sender, msg.value, currentReward);
    }

    // @notice user balance 
    function userBalance() public view returns(uint){
        return balances[msg.sender];
    }

    // @notice last update
    function lasTupdate() public view returns(uint){
        return lastUpdates[msg.sender];
    }

    // @notice pool balance 
    function poolBal() public view returns(uint){
        return poolBalance;
    }
}