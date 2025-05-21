// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingFarm is Ownable, ReentrancyGuard {
    struct TokenInfo {
        bool allowed;
        uint256 depositFeeBP;
        uint256 withdrawFeeBP;
        uint256 totalStaked;
        uint256 rewardRate; // annual reward rate in basis points
    }

    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => TokenInfo) public tokenWhitelist;
    mapping(address => mapping(address => StakeInfo)) public stakes;

    address public rewardVault;
    uint256 public constant TIMELOCK = 7 days;
    uint256 public constant EARLY_WITHDRAW_FEE_BP = 2000; // 20%

    event TokenWhitelisted(address token, bool allowed);
    event FeesUpdated(address token, uint256 depositFeeBP, uint256 withdrawFeeBP);
    event TokensStaked(address user, address token, uint256 amount);
    event TokensWithdrawn(address user, address token, uint256 amount);
    event EarlyWithdrawal(address user, address token, uint256 amount);
    event RewardVaultUpdated(address vault);

    modifier onlyWhitelisted(address token) {
        require(tokenWhitelist[token].allowed, "Token not whitelisted");
        _;
    }

    constructor(address _rewardVault) Ownable(msg.sender) {
        rewardVault = _rewardVault;
    }

    function updateRewardVault(address _vault) external onlyOwner {
        rewardVault = _vault;
        emit RewardVaultUpdated(_vault);
    }

    function setTokenWhitelist(address token, bool allowed, uint256 depositFeeBP, uint256 withdrawFeeBP, uint256 rewardRateBP) external onlyOwner {
        tokenWhitelist[token] = TokenInfo({
            allowed: allowed,
            depositFeeBP: depositFeeBP,
            withdrawFeeBP: withdrawFeeBP,
            totalStaked: tokenWhitelist[token].totalStaked,
            rewardRate: rewardRateBP
        });
        emit TokenWhitelisted(token, allowed);
    }

    function setFees(address token, uint256 depositFeeBP, uint256 withdrawFeeBP) external onlyOwner onlyWhitelisted(token) {
        tokenWhitelist[token].depositFeeBP = depositFeeBP;
        tokenWhitelist[token].withdrawFeeBP = withdrawFeeBP;
        emit FeesUpdated(token, depositFeeBP, withdrawFeeBP);
    }

    function stake(address token, uint256 amount) external nonReentrant onlyWhitelisted(token) {
        require(amount > 0, "Cannot stake 0");

        uint256 fee = (amount * tokenWhitelist[token].depositFeeBP) / 10000;
        uint256 amountAfterFee = amount - fee;

        IERC20(token).transferFrom(msg.sender, address(this), amountAfterFee);
        if (fee > 0) {
            IERC20(token).transferFrom(msg.sender, rewardVault, fee);
        }

        stakes[msg.sender][token].amount += amountAfterFee;
        stakes[msg.sender][token].timestamp = block.timestamp;
        tokenWhitelist[token].totalStaked += amountAfterFee;

        emit TokensStaked(msg.sender, token, amountAfterFee);
    }

    function withdraw(address token, uint256 amount) external nonReentrant onlyWhitelisted(token) {
        StakeInfo storage userStake = stakes[msg.sender][token];
        require(userStake.amount >= amount, "Insufficient balance");
        require(block.timestamp >= userStake.timestamp + TIMELOCK, "Tokens are locked");

        uint256 fee = (amount * tokenWhitelist[token].withdrawFeeBP) / 10000;
        uint256 amountAfterFee = amount - fee;

        userStake.amount -= amount;
        tokenWhitelist[token].totalStaked -= amount;

        IERC20(token).transfer(msg.sender, amountAfterFee);
        if (fee > 0) {
            IERC20(token).transfer(rewardVault, fee);
        }

        emit TokensWithdrawn(msg.sender, token, amountAfterFee);
    }

    function earlyWithdraw(address token, uint256 amount) external nonReentrant onlyWhitelisted(token) {
        StakeInfo storage userStake = stakes[msg.sender][token];
        require(userStake.amount >= amount, "Insufficient balance");
        require(block.timestamp < userStake.timestamp + TIMELOCK, "Timelock has passed");

        uint256 fee = (amount * (tokenWhitelist[token].withdrawFeeBP + EARLY_WITHDRAW_FEE_BP)) / 10000;
        uint256 amountAfterFee = amount - fee;

        userStake.amount -= amount;
        tokenWhitelist[token].totalStaked -= amount;

        IERC20(token).transfer(msg.sender, amountAfterFee);
        IERC20(token).transfer(rewardVault, fee);

        emit EarlyWithdrawal(msg.sender, token, amountAfterFee);
    }

    function getAPR(address token) external view returns (uint256) {
        return tokenWhitelist[token].rewardRate;
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return stakes[user][token].amount;
    }
}
