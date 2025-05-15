# KekiusFarm Contract

## Overview

The ` KekiusFarm ` contract is a Solidity smart contract designed for the Ethereum blockchain, enabling users to stake various ERC20 tokens and Uniswap V2 liquidity pool (LP) pairs to earn rewards in Kekius Maximus (KEKIUS) and Wrapped Ether (WETH). The contract includes a fee structure, cooldown periods, a whitelist-based proposal system for adding/removing tokens or pairs, and reward distribution mechanisms. It integrates with Uniswap V2 for token swaps to manage reward pools.

### Key Features
- **Token and Pair Staking**: Users can stake supported tokens (e.g., KEKIUS, WETH, USDT, SHIBA, BTC, BNB, PEPE, SOL, DOGE) and Uniswap V2 LP pairs (e.g., KEKIUS-WETH).
- **Fee Structure**:
  - Token staking: 6% deposit/withdrawal fee (2% for KEKIUS).
  - Pair staking: 3% deposit/withdrawal fee.
- **Reward Pools**: Fees are converted to KEKIUS and WETH via Uniswap V2, funding reward pools.
- **Reward Distribution**:
  - Token stakers earn KEKIUS rewards (25% of 1% KEKIUS pool per cycle).
  - Pair stakers earn KEKIUS rewards (25% of 1% KEKIUS pool per cycle).
  - KEKIUS stakers earn extra KEKIUS (10% of 1% KEKIUS pool) and WETH (50% of 1% WETH pool).
  - Pair stakers earn extra KEKIUS (15% of 1% KEKIUS pool) and WETH (50% of 1% WETH pool).
- **Cooldown Periods**: 7 days for token unstaking, 30 days for pair unstaking.
- **Proposal System**: Whitelisted users can propose adding/removing tokens or pairs, requiring 3 approvals.
- **Owner Controls**: The owner can add/remove tokens/pairs directly, manage the whitelist, and deploy the contract.
- **Security**: Uses OpenZeppelin's ` ReentrancyGuard ` and ` Ownable ` , with Uniswap V2 integration for swaps.

## Contract Details

- **Solidity Version**: 0.8.30
- **License**: MIT
- **Dependencies**:
  - OpenZeppelin Contracts (` IERC20 ` , ` ReentrancyGuard ` , ` Ownable ` )
  - Uniswap V2 Periphery (` IUniswapV2Router02 ` )
- **Deployment Chain**: Ethereum
- **Key Addresses**:
  - KEKIUS: ` 0x26E550AC11B26f78A04489d5F20f24E3559f7Ddisenä
  - WETH: ` 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 `
  - USDT: ` 0xdAC17F958D2ee523a2206206994597C13D831ec7 `
  - SHIBA: ` 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE `
  - BTC: ` 0x9BE89D2a4cd102D8Fecc6BF9dA793be995C22541 `
  - BNB: ` 0xB8c77482e45F1F44dE1745F52C74426C631bDD52 `
  - PEPE: ` 0x6982508145454Ce325dDbE47a25d4ec3d2311933 `
  - SOL: ` 0xD31a59c85aE9D8edEFeC411D448f90841571b89c `
  - DOGE: ` 0x1121AcC14c63f3C872BFcA497d10926A6098AAc5 `
  - KEKIUS-WETH Pair: ` 0xFFf8D5fFF6Ee3226fa2F5d7D5D8C3Ff785be9C74 `
- **Constants**:
  - Cycle Length: 7,777 blocks (~1 day).
  - Precision: 1e18 for reward calculations.

## Setup

### Prerequisites
- **Node.js** and **npm** for Hardhat or Foundry.
- **Ethereum Node Provider** (e.g., Alchemy, Infura) for deployment.
- **Uniswap V2 Router**: Provide the Uniswap V2 Router address (e.g., ` 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D ` ).
- **Wallet**: A wallet with ETH for gas and tokens for testing.
- **Token Approvals**: Users must approve the contract to spend their tokens/pairs.

### Installation
1. **Clone the Repository**:
   ``` bash
   git clone <repository-url>
   cd kekius-farm
   ```

2. **Install Dependencies**:
   Using Hardhat:
   ``` bash
   npm install @openzeppelin/contracts @uniswap/v2-periphery
   ```

3. **Configure Environment**:
   Create a ` .env ` file with:
   ```
   ETHEREUM_RPC_URL=<your-ethereum-rpc-url>
   PRIVATE_KEY=<your-wallet-private-key>
   ```

4. **Compile the Contract**:
   ``` bash
   npx hardhat compile
   ```

## Deployment

1. **Verify Addresses**:
   - Ensure token and pair addresses match the Ethereum mainnet.
   - Confirm the Uniswap V2 Router address.

2. **Deploy the Contract**:
   Use a Hardhat script or Foundry, passing the Uniswap V2 Router address:
   ``` javascript
   const KekiusFarm = await ethers.getContractFactory("KekiusFarm");
   const kekiusFarm = await KekiusFarm.deploy("<uniswap-router-address>");
   await kekiusFarm.deployed();
   console.log("KekiusFarm deployed to:", kekiusFarm.address);
   ```

3. **Verify the Contract**:
   Verify on Etherscan:
   ``` bash
   npx hardhat verify --network mainnet <contract-address> "<uniswap-router-address>"
   ```

## Usage

### Staking Tokens
1. **Approve Tokens**:
   Approve the ` KekiusFarm ` contract to spend tokens:
   ``` javascript
   const token = await ethers.getContractAt("IERC20", "<token-address>");
   await token.approve("<kekius-farm-address>", ethers.utils.parseUnits("<amount>", 18));
   ```

2. **Stake Tokens**:
   Call ` stakeToken ` :
   ``` javascript
   const kekiusFarm = await ethers.getContractAt("KekiusFarm", "<kekius-farm-address>");
   await kekiusFarm.stakeToken("<token-address>", ethers.utils.parseUnits("<amount>", 18));
   ```
   - **Fee**: 6% (2% for KEKIUS) is deducted and added to reward pools.
   - **Cooldown**: 7 days before unstaking.

### Staking Pairs
1. **Approve LP Tokens**:
   Approve the contract to spend Uniswap V2 LP tokens:
   ``` javascript
   const pair = await ethers.getContractAt("IERC20", "<pair-address>");
   await pair.approve("<kekius-farm-address>", ethers.utils.parseUnits("<amount>", 18));
   ```

2. **Stake Pairs**:
   Call ` stakePair ` :
   ``` javascript
   await kekiusFarm.stakePair("<pair-address>", ethers.utils.parseUnits("<amount>", 18));
   ```
   - **Fee**: 3% is deducted and added to reward pools.
   - **Cooldown**: 30 days before unstaking.

### Unstaking
- **Unstake Tokens**:
   ``` javascript
   await kekiusFarm.unstakeToken("<token-address>", ethers.utils.parseUnits("<amount>", 18));
   ```
- **Unstake Pairs**:
   ``` javascript
   await kekiusFarm.unstakePair("<pair-address>", ethers.utils.parseUnits("<amount>", 18));
   ```
   - Ensure cooldown periods are met.
   - Fees apply (6% for tokens, 2% for KEKIUS, 3% for pairs).

### Claiming Rewards
- Call ` claimRewards ` to receive KEKIUS and WETH rewards:
   ``` javascript
   await kekiusFarm.claimRewards();
   ```
   - Rewards are calculated based on staked amounts and accumulated shares.
   - View pending rewards with ` getPendingRewards(<user-address>) ` .

### Proposal System
1. **Create Proposal** (whitelisted users):
   ``` javascript
   await kekiusFarm.createProposal("<token-or-pair-address>", <isPair>, <isAdd>);
   ```
2. **Approve Proposal** (whitelisted users):
   ``` javascript
   await kekiusFarm.approveProposal(<proposalId>);
   ```
   - Requires 3 approvals to execute.
   - Adds/removes tokens or pairs from allowed lists.

### Owner Functions
- **Add/Remove Whitelist**:
   ``` javascript
   await kekiusFarm.addToWhitelist("<address>");
   await kekiusFarm.removeFromWhitelist("<address>");
   ```
- **Add/Remove Tokens/Pairs**:
   ``` javascript
   await kekiusFarm.addTokenOrPair("<token-or-pair-address>", <isPair>);
   await kekiusFarm.removeTokenOrPair("<token-or-pair-address>", <isPair>);
   ```

## Events
- **Staked**:
  ``` solidity
  event Staked(address indexed user, address indexed tokenOrPair, uint256 amount, bool isPair);
  ```
- **Unstaked**:
  ``` solidity
  event Unstaked(address indexed user, address indexed tokenOrPair, uint256 amount, bool isPair);
  ```
- **RewardsClaimed**:
  ``` solidity
  event RewardsClaimed(address indexed user, uint256 kekiusAmount, uint256 wethAmount);
  ```
- **TokenOrPairAdded/Removed**:
  ``` solidity
  event TokenOrPairAdded(address indexed tokenOrPair, bool isPair);
  event TokenOrPairRemoved(address indexed tokenOrPair, bool isPair);
  ```
- **ProposalCreated/Approved**:
  ``` solidity
  event ProposalCreated(uint256 proposalId, address tokenOrPair, bool isPair, bool isAdd);
  event ProposalApproved(uint256 proposalId, address approver);
  ```

## Security Considerations
- **Reentrancy**: Mitigated using ` ReentrancyGuard ` .
- **Uniswap Swaps**: Ensure sufficient liquidity and consider minimum output amounts in production.
- **Cooldown Periods**: Prevent rapid stake/unstake cycles.
- **Whitelist**: Secure whitelist management to control proposals.
- **Reward Pools**: Ensure pools are funded to avoid reward failures.
- **Audits**: Conduct thorough audits due to complex reward calculations and external integrations.

## Testing
1. **Test Environment**: Use Ethereum testnets (e.g., Sepo'slia).
2. **Test Cases**:
   - Stake/unstake tokens and pairs, verify fees and reward pools.
   - Claim rewards and check calculations.
   - Test proposal system (create, approve, execute).
   - Test owner and whitelist functions.
3. **Tools**: Hardhat, Foundry, or Mocha/Chai.

## Notes
- **Token Addresses**: Verify all token and pair addresses on Ethereum mainnet.
- **Uniswap Router**: Use the official Uniswap V2 Router address.
- **Reward Distribution**: Rewards are updated every 7,777 blocks (~1 day).
- **Gas Costs**: Monitor gas usage for staking and reward claiming.
- **Decimals**: Most tokens use 18 decimals; verify for each token.

## License
MIT License

---
For issues or contributions, please open a pull request or contact the repository maintainer.
