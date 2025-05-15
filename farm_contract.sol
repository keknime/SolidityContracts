// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title KekiusFarm
 * @dev A farming contract for Kekius Maximus token with staking, fees, and reward distribution.
 */
contract KekiusFarm is ReentrancyGuard, Ownable {
    // **Constants**
    address public constant KEKIUS = 0x26E550AC11B26f78A04489d5F20f24E3559f7Dd9;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant SHIBA = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address public constant BTC = 0x9BE89D2a4cd102D8Fecc6BF9dA793be995C22541;
    address public constant BNB = 0xB8c77482e45F1F44dE1745F52C74426C631bDD52;
    address public constant PEPE = 0x6982508145454Ce325dDbE47a25d4ec3d2311933;
    address public constant SOL = 0xD31a59c85aE9D8edEFeC411D448f90841571b89c;
    address public constant DOGE = 0x1121AcC14c63f3C872BFcA497d10926A6098AAc5;
    address public constant KEKIUS_WETH_PAIR = 0xFFf8D5fFF6Ee3226fa2F5d7D5D8C3Ff785be9C74;

    IUniswapV2Router02 public immutable router;

    uint256 public constant TOKEN_DEPOSIT_FEE_BP = 600;  // 6%
    uint256 public constant TOKEN_WITHDRAW_FEE_BP = 600; // 6%
    uint256 public constant PAIR_DEPOSIT_FEE_BP = 300;   // 3%
    uint256 public constant PAIR_WITHDRAW_FEE_BP = 300;  // 3%
    uint256 public constant KEKIUS_FEE_BP = 200;         // 2%
    uint256 public constant BP_DENOMINATOR = 10000;
    uint256 public constant TOKEN_COOLDOWN = 7 days;
    uint256 public constant PAIR_COOLDOWN = 30 days;
    uint256 public constant BLOCKS_PER_CYCLE = 7777;    // Approx. 1 day
    uint256 public constant PRECISION = 1e18;

    // **State Variables**
    mapping(address => bool) public allowedTokens;
    mapping(address => bool) public allowedPairs;
    address[] public allowedTokenList;
    address[] public allowedPairList;

    mapping(address => mapping(address => uint256)) public stakedTokens; // user => token => amount
    mapping(address => mapping(address => uint256)) public stakedPairs;  // user => pair => amount
    mapping(address => uint256) public totalStakedTokens;               // token => total staked
    mapping(address => uint256) public totalStakedPairs;                // pair => total staked
    uint256 public totalPairStaked;

    mapping(address => mapping(address => uint256)) public lastActionTimeTokens; // user => token => timestamp
    mapping(address => mapping(address => uint256)) public lastActionTimePairs;  // user => pair => timestamp

    uint256 public kekiusRewardPool;
    uint256 public wethRewardPool;

    mapping(address => bool) public whitelist;
    struct Proposal {
        address tokenOrPair;
        bool isPair;
        bool isAdd;
        mapping(address => bool) approvals;
        uint256 approvalCount;
        bool executed;
    }
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    uint256 public lastUpdateBlock;

    mapping(address => uint256) public accKekiusPerShareTokens; // token => acc reward per share
    mapping(address => uint256) public accKekiusPerSharePairs;  // pair => acc reward per share
    uint256 public accExtraKekiusPerShare;                     // for Kekius token stakers
    uint256 public accExtraPairPerShare;                       // for all pair stakers
    uint256 public accWethPerShareKekius;                      // for Kekius token stakers
    uint256 public accWethPerSharePairs;                       // for all pair stakers

    mapping(address => mapping(address => uint256)) public rewardDebtTokens;    // user => token => reward debt
    mapping(address => mapping(address => uint256)) public rewardDebtPairs;     // user => pair => reward debt
    mapping(address => uint256) public rewardDebtExtraKekius;                   // user => extra Kekius reward debt
    mapping(address => uint256) public userTotalPairStaked;                     // user => total staked in all pairs
    mapping(address => uint256) public rewardDebtExtraPair;                     // user => extra pair reward debt
    mapping(address => uint256) public rewardDebtWethKekius;                    // user => WETH reward debt (Kekius staking)
    mapping(address => uint256) public rewardDebtWethPairs;                     // user => WETH reward debt (pair staking)

    // **Events**
    event Staked(address indexed user, address indexed tokenOrPair, uint256 amount, bool isPair);
    event Unstaked(address indexed user, address indexed tokenOrPair, uint256 amount, bool isPair);
    event RewardsClaimed(address indexed user, uint256 kekiusAmount, uint256 wethAmount);
    event TokenOrPairAdded(address indexed tokenOrPair, bool isPair);
    event TokenOrPairRemoved(address indexed tokenOrPair, bool isPair);
    event ProposalCreated(uint256 proposalId, address tokenOrPair, bool isPair, bool isAdd);
    event ProposalApproved(uint256 proposalId, address approver);

    /**
     * @dev Constructor initializes the contract with the Uniswap router and initial tokens/pairs.
     * @param _router Address of the Uniswap V2 Router.
     */
    constructor(address _router) Ownable(msg.sender) {
        router = IUniswapV2Router02(_router);
        allowedTokens[KEKIUS] = true;
        allowedTokens[WETH] = true;
        allowedTokens[USDT] = true;
        allowedTokens[SHIBA] = true;
        allowedTokens[BTC] = true;
        allowedTokens[BNB] = true;
        allowedTokens[PEPE] = true;
        allowedTokens[SOL] = true;
        allowedTokens[DOGE] = true;
        allowedTokenList = [KEKIUS, WETH, USDT, SHIBA, BTC, BNB, PEPE, SOL, DOGE];
        allowedPairs[KEKIUS_WETH_PAIR] = true;
        allowedPairList = [KEKIUS_WETH_PAIR];
        lastUpdateBlock = block.number;
    }

    // **Whitelist Management**
    function addToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    // **Proposal System**
    function createProposal(address _tokenOrPair, bool _isPair, bool _isAdd) external {
        require(whitelist[msg.sender], "Not whitelisted");
        require(_tokenOrPair != address(0), "Invalid address");
        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.tokenOrPair = _tokenOrPair;
        p.isPair = _isPair;
        p.isAdd = _isAdd;
        p.approvalCount = 0;
        p.executed = false;
        emit ProposalCreated(proposalCount, _tokenOrPair, _isPair, _isAdd);
    }

    function approveProposal(uint256 _proposalId) external {
        require(whitelist[msg.sender], "Not whitelisted");
        Proposal storage p = proposals[_proposalId];
        require(!p.executed, "Already executed");
        require(!p.approvals[msg.sender], "Already approved");
        p.approvals[msg.sender] = true;
        p.approvalCount++;
        emit ProposalApproved(_proposalId, msg.sender);
        if (p.approvalCount >= 3) {
            p.executed = true;
            if (p.isAdd) {
                if (p.isPair) {
                    if (!allowedPairs[p.tokenOrPair]) {
                        allowedPairs[p.tokenOrPair] = true;
                        allowedPairList.push(p.tokenOrPair);
                        emit TokenOrPairAdded(p.tokenOrPair, true);
                    }
                } else {
                    if (!allowedTokens[p.tokenOrPair]) {
                        allowedTokens[p.tokenOrPair] = true;
                        allowedTokenList.push(p.tokenOrPair);
                        emit TokenOrPairAdded(p.tokenOrPair, false);
                    }
                }
            } else {
                if (p.isPair) {
                    require(totalStakedPairs[p.tokenOrPair] == 0, "Cannot remove pair with active stakes");
                    allowedPairs[p.tokenOrPair] = false;
                    emit TokenOrPairRemoved(p.tokenOrPair, true);
                } else {
                    require(totalStakedTokens[p.tokenOrPair] == 0, "Cannot remove token with active stakes");
                    allowedTokens[p.tokenOrPair] = false;
                    emit TokenOrPairRemoved(p.tokenOrPair, false);
                }
            }
        }
    }

    // **Direct Add/Remove by Owner**
    function addTokenOrPair(address _tokenOrPair, bool _isPair) external onlyOwner {
        require(_tokenOrPair != address(0), "Invalid address");
        if (_isPair) {
            if (!allowedPairs[_tokenOrPair]) {
                allowedPairs[_tokenOrPair] = true;
                allowedPairList.push(_tokenOrPair);
                emit TokenOrPairAdded(_tokenOrPair, true);
            }
        } else {
            if (!allowedTokens[_tokenOrPair]) {
                allowedTokens[_tokenOrPair] = true;
                allowedTokenList.push(_tokenOrPair);
                emit TokenOrPairAdded(_tokenOrPair, false);
            }
        }
    }

    function removeTokenOrPair(address _tokenOrPair, bool _isPair) external onlyOwner {
        if (_isPair) {
            require(totalStakedPairs[_tokenOrPair] == 0, "Cannot remove pair with active stakes");
            allowedPairs[_tokenOrPair] = false;
            emit TokenOrPairRemoved(_tokenOrPair, true);
        } else {
            require(totalStakedTokens[_tokenOrPair] == 0, "Cannot remove token with active stakes");
            allowedTokens[_tokenOrPair] = false;
            emit TokenOrPairRemoved(_tokenOrPair, false);
        }
    }

    // **Staking Functions**
    function stakeToken(address token, uint256 amount) external nonReentrant {
        require(allowedTokens[token], "Token not allowed");
        require(amount > 0, "Amount must be greater than 0");
        updateRewards();
        uint256 fee = calculateFee(token, amount, true);
        uint256 amountAfterFee = amount - fee;
        stakedTokens[msg.sender][token] += amountAfterFee;
        totalStakedTokens[token] += amountAfterFee;
        if (token == KEKIUS) {
            rewardDebtExtraKekius[msg.sender] = stakedTokens[msg.sender][token] * accExtraKekiusPerShare / PRECISION;
            rewardDebtWethKekius[msg.sender] = stakedTokens[msg.sender][token] * accWethPerShareKekius / PRECISION;
        }
        rewardDebtTokens[msg.sender][token] = stakedTokens[msg.sender][token] * accKekiusPerShareTokens[token] / PRECISION;
        lastActionTimeTokens[msg.sender][token] = block.timestamp;
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        if (fee > 0) addToRewardPool(token, fee);
        emit Staked(msg.sender, token, amountAfterFee, false);
    }

    function unstakeToken(address token, uint256 amount) external nonReentrant {
        require(allowedTokens[token], "Token not allowed");
        require(stakedTokens[msg.sender][token] >= amount, "Insufficient staked amount");
        require(block.timestamp >= lastActionTimeTokens[msg.sender][token] + TOKEN_COOLDOWN, "Cooldown period not passed");
        updateRewards();
        uint256 fee = calculateFee(token, amount, false);
        uint256 amountAfterFee = amount - fee;
        stakedTokens[msg.sender][token] -= amount;
        totalStakedTokens[token] -= amount;
        if (token == KEKIUS) {
            rewardDebtExtraKekius[msg.sender] = stakedTokens[msg.sender][token] * accExtraKekiusPerShare / PRECISION;
            rewardDebtWethKekius[msg.sender] = stakedTokens[msg.sender][token] * accWethPerShareKekius / PRECISION;
        }
        rewardDebtTokens[msg.sender][token] = stakedTokens[msg.sender][token] * accKekiusPerShareTokens[token] / PRECISION;
        lastActionTimeTokens[msg.sender][token] = block.timestamp;
        require(IERC20(token).transfer(msg.sender, amountAfterFee), "Transfer failed");
        if (fee > 0) addToRewardPool(token, fee);
        emit Unstaked(msg.sender, token, amountAfterFee, false);
    }

    function stakePair(address pair, uint256 amount) external nonReentrant {
        require(allowedPairs[pair], "Pair not allowed");
        require(amount > 0, "Amount must be greater than 0");
        updateRewards();
        uint256 fee = calculateFee(pair, amount, true);
        uint256 amountAfterFee = amount - fee;
        stakedPairs[msg.sender][pair] += amountAfterFee;
        totalStakedPairs[pair] += amountAfterFee;
        userTotalPairStaked[msg.sender] += amountAfterFee;
        totalPairStaked += amountAfterFee;
        rewardDebtPairs[msg.sender][pair] = stakedPairs[msg.sender][pair] * accKekiusPerSharePairs[pair] / PRECISION;
        rewardDebtExtraPair[msg.sender] = userTotalPairStaked[msg.sender] * accExtraPairPerShare / PRECISION;
        rewardDebtWethPairs[msg.sender] = userTotalPairStaked[msg.sender] * accWethPerSharePairs / PRECISION;
        lastActionTimePairs[msg.sender][pair] = block.timestamp;
        require(IERC20(pair).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        if (fee > 0) addToRewardPool(pair, fee);
        emit Staked(msg.sender, pair, amountAfterFee, true);
    }

    function unstakePair(address pair, uint256 amount) external nonReentrant {
        require(allowedPairs[pair], "Pair not allowed");
        require(stakedPairs[msg.sender][pair] >= amount, "Insufficient staked amount");
        require(block.timestamp >= lastActionTimePairs[msg.sender][pair] + PAIR_COOLDOWN, "Cooldown period not passed");
        updateRewards();
        uint256 fee = calculateFee(pair, amount, false);
        uint256 amountAfterFee = amount - fee;
        stakedPairs[msg.sender][pair] -= amount;
        totalStakedPairs[pair] -= amount;
        userTotalPairStaked[msg.sender] -= amount;
        totalPairStaked -= amount;
        rewardDebtPairs[msg.sender][pair] = stakedPairs[msg.sender][pair] * accKekiusPerSharePairs[pair] / PRECISION;
        rewardDebtExtraPair[msg.sender] = userTotalPairStaked[msg.sender] * accExtraPairPerShare / PRECISION;
        rewardDebtWethPairs[msg.sender] = userTotalPairStaked[msg.sender] * accWethPerSharePairs / PRECISION;
        lastActionTimePairs[msg.sender][pair] = block.timestamp;
        require(IERC20(pair).transfer(msg.sender, amountAfterFee), "Transfer failed");
        if (fee > 0) addToRewardPool(pair, fee);
        emit Unstaked(msg.sender, pair, amountAfterFee, true);
    }

    // **Reward Claiming**
    function claimRewards() external nonReentrant {
        updateRewards();
        uint256 pendingKekius = 0;
        uint256 pendingWeth = 0;

        // Token staking rewards
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            address token = allowedTokenList[i];
            if (allowedTokens[token] && stakedTokens[msg.sender][token] > 0) {
                uint256 pending = (stakedTokens[msg.sender][token] * accKekiusPerShareTokens[token] / PRECISION) - rewardDebtTokens[msg.sender][token];
                pendingKekius += pending;
                rewardDebtTokens[msg.sender][token] = stakedTokens[msg.sender][token] * accKekiusPerShareTokens[token] / PRECISION;
            }
        }

        // Pair staking rewards
        for (uint256 i = 0; i < allowedPairList.length; i++) {
            address pair = allowedPairList[i];
            if (allowedPairs[pair] && stakedPairs[msg.sender][pair] > 0) {
                uint256 pending = (stakedPairs[msg.sender][pair] * accKekiusPerSharePairs[pair] / PRECISION) - rewardDebtPairs[msg.sender][pair];
                pendingKekius += pending;
                rewardDebtPairs[msg.sender][pair] = stakedPairs[msg.sender][pair] * accKekiusPerSharePairs[pair] / PRECISION;
            }
        }

        // Extra Kekius rewards from Kekius staking
        if (stakedTokens[msg.sender][KEKIUS] > 0) {
            uint256 pendingExtra = (stakedTokens[msg.sender][KEKIUS] * accExtraKekiusPerShare / PRECISION) - rewardDebtExtraKekius[msg.sender];
            pendingKekius += pendingExtra;
            rewardDebtExtraKekius[msg.sender] = stakedTokens[msg.sender][KEKIUS] * accExtraKekiusPerShare / PRECISION;
        }

        // Extra Kekius rewards from pair staking
        if (userTotalPairStaked[msg.sender] > 0) {
            uint256 pendingExtraPair = (userTotalPairStaked[msg.sender] * accExtraPairPerShare / PRECISION) - rewardDebtExtraPair[msg.sender];
            pendingKekius += pendingExtraPair;
            rewardDebtExtraPair[msg.sender] = userTotalPairStaked[msg.sender] * accExtraPairPerShare / PRECISION;
        }

        // WETH rewards from Kekius staking
        if (stakedTokens[msg.sender][KEKIUS] > 0) {
            uint256 pendingWethKekius = (stakedTokens[msg.sender][KEKIUS] * accWethPerShareKekius / PRECISION) - rewardDebtWethKekius[msg.sender];
            pendingWeth += pendingWethKekius;
            rewardDebtWethKekius[msg.sender] = stakedTokens[msg.sender][KEKIUS] * accWethPerShareKekius / PRECISION;
        }

        // WETH rewards from pair staking
        if (userTotalPairStaked[msg.sender] > 0) {
            uint256 pendingWethPairs = (userTotalPairStaked[msg.sender] * accWethPerSharePairs / PRECISION) - rewardDebtWethPairs[msg.sender];
            pendingWeth += pendingWethPairs;
            rewardDebtWethPairs[msg.sender] = userTotalPairStaked[msg.sender] * accWethPerSharePairs / PRECISION;
        }

        // Transfer rewards
        if (pendingKekius > 0) {
            require(kekiusRewardPool >= pendingKekius, "Insufficient Kekius reward pool");
            kekiusRewardPool -= pendingKekius;
            require(IERC20(KEKIUS).transfer(msg.sender, pendingKekius), "Kekius transfer failed");
        }
        if (pendingWeth > 0) {
            require(wethRewardPool >= pendingWeth, "Insufficient WETH reward pool");
            wethRewardPool -= pendingWeth;
            require(IERC20(WETH).transfer(msg.sender, pendingWeth), "WETH transfer failed");
        }
        emit RewardsClaimed(msg.sender, pendingKekius, pendingWeth);
    }

    // **Internal Functions**
    function calculateFee(address tokenOrPair, uint256 amount, bool isDeposit) public view returns (uint256) {
        uint256 feeBP;
        if (tokenOrPair == KEKIUS) {
            feeBP = KEKIUS_FEE_BP;
        } else if (allowedTokens[tokenOrPair]) {
            feeBP = isDeposit ? TOKEN_DEPOSIT_FEE_BP : TOKEN_WITHDRAW_FEE_BP;
        } else if (allowedPairs[tokenOrPair]) {
            feeBP = isDeposit ? PAIR_DEPOSIT_FEE_BP : PAIR_WITHDRAW_FEE_BP;
        } else {
            revert("Invalid token or pair");
        }
        return (amount * feeBP) / BP_DENOMINATOR;
    }

    function addToRewardPool(address feeToken, uint256 feeAmount) internal {
        IERC20 feeERC20 = IERC20(feeToken);
        require(feeERC20.approve(address(router), feeAmount), "Approval failed");
        uint256 half = feeAmount / 2;
        if (feeToken != KEKIUS) {
            uint256 kekiusAmount = swapTokenToToken(feeToken, half, KEKIUS);
            kekiusRewardPool += kekiusAmount;
        } else {
            kekiusRewardPool += half;
        }
        if (feeToken != WETH) {
            uint256 wethAmount = swapTokenToToken(feeToken, feeAmount - half, WETH);
            wethRewardPool += wethAmount;
        } else {
            wethRewardPool += half;
        }
    }

    function swapTokenToToken(address fromToken, uint256 amount, address toToken) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amount,
            0, // Consider adding minimum amount for production
            path,
            address(this),
            block.timestamp + 300
        );
        return amounts[1];
    }

    function updateRewards() internal {
        uint256 blocksElapsed = block.number - lastUpdateBlock;
        if (blocksElapsed == 0) return;
        uint256 currentKekiusPool = kekiusRewardPool;
        uint256 currentWethPool = wethRewardPool;

        // Count active tokens and pairs
        uint256 n = 0;
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            if (allowedTokens[allowedTokenList[i]]) n++;
        }
        uint256 m = 0;
        for (uint256 i = 0; i < allowedPairList.length; i++) {
            if (allowedPairs[allowedPairList[i]]) m++;
        }

        // Update token staking rewards (25% of 1% Kekius pool)
        if (n > 0 && currentKekiusPool > 0) {
            for (uint256 i = 0; i < allowedTokenList.length; i++) {
                address token = allowedTokenList[i];
                if (allowedTokens[token] && totalStakedTokens[token] > 0) {
                    accKekiusPerShareTokens[token] += (blocksElapsed * 25 * currentKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * n * totalStakedTokens[token]);
                }
            }
        }

        // Update pair staking rewards (25% of 1% Kekius pool)
        if (m > 0 && currentKekiusPool > 0) {
            for (uint256 i = 0; i < allowedPairList.length; i++) {
                address pair = allowedPairList[i];
                if (allowedPairs[pair] && totalStakedPairs[pair] > 0) {
                    accKekiusPerSharePairs[pair] += (blocksElapsed * 25 * currentKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * m * totalStakedPairs[pair]);
                }
            }
        }

        // Update extra rewards
        if (totalStakedTokens[KEKIUS] > 0) {
            if (currentKekiusPool > 0) {
                accExtraKekiusPerShare += (blocksElapsed * 10 * currentKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalStakedTokens[KEKIUS]);
            }
            if (currentWethPool > 0) {
                accWethPerShareKekius += (blocksElapsed * 50 * currentWethPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalStakedTokens[KEKIUS]);
            }
        }
        if (totalPairStaked > 0) {
            if (currentKekiusPool > 0) {
                accExtraPairPerShare += (blocksElapsed * 15 * currentKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalPairStaked);
            }
            if (currentWethPool > 0) {
                accWethPerSharePairs += (blocksElapsed * 50 * currentWethPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalPairStaked);
            }
        }
        lastUpdateBlock = block.number;
    }

    // **View Functions**
    function getPendingRewards(address user) external view returns (uint256 pendingKekius, uint256 pendingWeth) {
        uint256 tempKekiusPool = kekiusRewardPool;
        uint256 tempWethPool = wethRewardPool;
        uint256 blocksElapsed = block.number - lastUpdateBlock;
        uint256 n = 0;
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            if (allowedTokens[allowedTokenList[i]]) n++;
        }
        uint256 m = 0;
        for (uint256 i = 0; i < allowedPairList.length; i++) {
            if (allowedPairs[allowedPairList[i]]) m++;
        }

        // Token staking rewards
        for (uint256 i = 0; i < allowedTokenList.length; i++) {
            address token = allowedTokenList[i];
            if (allowedTokens[token] && stakedTokens[user][token] > 0) {
                uint256 accKekius = accKekiusPerShareTokens[token];
                if (n > 0 && totalStakedTokens[token] > 0 && tempKekiusPool > 0) {
                    accKekius += (blocksElapsed * 25 * tempKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * n * totalStakedTokens[token]);
                }
                pendingKekius += (stakedTokens[user][token] * accKekius / PRECISION) - rewardDebtTokens[user][token];
            }
        }

        // Pair staking rewards
        for (uint256 i = 0; i < allowedPairList.length; i++) {
            address pair = allowedPairList[i];
            if (allowedPairs[pair] && stakedPairs[user][pair] > 0) {
                uint256 accKekius = accKekiusPerSharePairs[pair];
                if (m > 0 && totalStakedPairs[pair] > 0 && tempKekiusPool > 0) {
                    accKekius += (blocksElapsed * 25 * tempKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * m * totalStakedPairs[pair]);
                }
                pendingKekius += (stakedPairs[user][pair] * accKekius / PRECISION) - rewardDebtPairs[user][pair];
            }
        }

        // Extra Kekius rewards
        if (stakedTokens[user][KEKIUS] > 0) {
            uint256 accExtra = accExtraKekiusPerShare;
            uint256 accWeth = accWethPerShareKekius;
            if (totalStakedTokens[KEKIUS] > 0) {
                if (tempKekiusPool > 0) {
                    accExtra += (blocksElapsed * 10 * tempKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalStakedTokens[KEKIUS]);
                }
                if (tempWethPool > 0) {
                    accWeth += (blocksElapsed * 50 * tempWethPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalStakedTokens[KEKIUS]);
                }
            }
            pendingKekius += (stakedTokens[user][KEKIUS] * accExtra / PRECISION) - rewardDebtExtraKekius[user];
            pendingWeth += (stakedTokens[user][KEKIUS] * accWeth / PRECISION) - rewardDebtWethKekius[user];
        }

        // Extra pair rewards
        if (userTotalPairStaked[user] > 0) {
            uint256 accExtraPair = accExtraPairPerShare;
            uint256 accWethPairs = accWethPerSharePairs;
            if (totalPairStaked > 0) {
                if (tempKekiusPool > 0) {
                    accExtraPair += (blocksElapsed * 15 * tempKekiusPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalPairStaked);
                }
                if (tempWethPool > 0) {
                    accWethPairs += (blocksElapsed * 50 * tempWethPool * PRECISION) / (100 * BLOCKS_PER_CYCLE * totalPairStaked);
                }
            }
            pendingKekius += (userTotalPairStaked[user] * accExtraPair / PRECISION) - rewardDebtExtraPair[user];
            pendingWeth += (userTotalPairStaked[user] * accWethPairs / PRECISION) - rewardDebtWethPairs[user];
        }
        return (pendingKekius, pendingWeth);
    }
}
