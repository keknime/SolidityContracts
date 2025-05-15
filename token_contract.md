# TokenFactory Contract

## Overview

The`TokenFactory`contract is a Solidity smart contract deployed on the Base chain, designed to allow users to create ERC20 tokens by specifying a token name, symbol, and total supply. Each token creation incurs a fee of 5 USDT, which is collected on the Base chain and bridged to a designated Ethereum address for the contract owner.

### Key Features
- **Token Creation**: Users can create ERC20 tokens with custom name, symbol, and total supply.
- **Fee Mechanism**: A 5 USDT fee is charged per token creation (USDT uses 6 decimals).
- **Cross-Chain Fee Transfer**: Fees are bridged from Base to Ethereum using a bridge contract (placeholder interface included).
- **Owner Controls**: The contract owner can update the bridge address and withdraw any stuck USDT.
- **Events**: Emits`TokenCreated`and`FeeBridged`events for tracking token creation and fee transfers.

## Contract Details

- **Solidity Version**: backslash backslash 0.8.30
- **Dependencies**:
  - OpenZeppelin Contracts (`ERC20`,`Ownable`)
  - USDT Interface (`IUSDT`) for handling USDT transfers and approvals
  - Bridge Interface (`IBridge`) for cross-chain USDT transfers
- **Deployment Chain**: Base
- **USDT Address**:`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`(verify the correct USDT address on Base)
- **Ethereum Fee Recipient**:`0xd57407f87FaeDea87d32C88beA92298A7B1D58E8`(replace with the desired Ethereum address)

## Setup

### Prerequisites
- **Node.js** and **npm** for Hardhat or Foundry.
- **Base Node Provider** (e.g., Alchemy, Infura) for deployment.
- **USDT Contract Address**: Confirm the USDT address on Base.
- **Bridge Contract**: A deployed bridge contract supporting USDT transfers from Base to Ethereum (e.g., LayerZero, Chainlink CCIP, or Base native bridge).
- **Wallet**: A wallet with ETH on Base for gas and USDT for testing.

### Installation
1. **Clone the Repository**:
  ```bash
   git clone <repository-url>
   cd token-factory
  ```

2. **Install Dependencies**:
   Using Hardhat:
  ```bash
   npm install @openzeppelin/contracts
  ```

3. **Configure Environment**:
   Create a`.env`file with:
  ```
   BASE_RPC_URL=<your-base-rpc-url>
   PRIVATE_KEY=<your-wallet-private-key>
  ```

4. **Compile the Contract**:
  ```bash
   npx hardhat compile
  ```

## Deployment

1. **Update Addresses**:
   - Replace`USDT_ADDRESS`in the contract with the actual USDT address on Base if different.
   - Replace`ETHEREUM_FEE_RECIPIENT`with the Ethereum address to receive fees.

2. **Deploy the Contract**:
   Use a Hardhat script or Foundry to deploy, passing the bridge contract address to the constructor:
  ```javascript
   const TokenFactory = await ethers.getContractFactory("TokenFactory");
   const tokenFactory = await TokenFactory.deploy("<bridge-contract-address>");
   await tokenFactory.deployed();
   console.log("TokenFactory deployed to:", tokenFactory.address);
  ```

3. **Verify the Contract**:
   Verify on BaseScan (Base chain explorer):
  ```bash
   npx hardhat verify --network base <contract-address> "<bridge-contract-address>"
  ```

## Usage

### Creating a Token
1. **Approve USDT**:
   Users must approve the`TokenFactory`contract to spend 5 USDT (6 decimals). Using ethers.js:
  ```javascript
   const usdt = await ethers.getContractAt("IERC20", "<usdt-address>");
   await usdt.approve("<token-factory-address>", ethers.utils.parseUnits("5", 6));
  ```

2. **Call`createToken`**:
   Call the`createToken`function with the token details:
  ```javascript
   const tokenFactory = await ethers.getContractAt("TokenFactory", "<token-factory-address>");
   await tokenFactory.createToken("MyToken", "MTK", ethers.utils.parseUnits("1000000", 18));
  ```

   - **Parameters**:
     -`name`: Token name (e.g., "MyToken")
     -`symbol`: Token symbol (e.g., "MTK")
     -`totalSupply`: Total supply in base units (e.g., 1,000,000 tokens)
   - **Outcome**:
     - A new ERC20 token is created.
     - 5 USDT is transferred from the user to the contract.
     - The USDT fee is bridged to the Ethereum recipient address.
     - Events`TokenCreated`and`FeeBridged`are emitted.

### Owner Functions
- **Update Bridge Address**:
  ```javascript
   await tokenFactory.setBridgeAddress("<new-bridge-address>");
  ```
- **Withdraw Stuck USDT**:
  ```javascript
   await tokenFactory.withdrawStuckUSDT();
  ```

## Events
- **TokenCreated**:
 ```solidity
  event TokenCreated(address indexed tokenAddress, string name, string symbol, uint256 totalSupply);
 ```
  Emitted when a new token is created.
- **FeeBridged**:
 ```solidity
  event FeeBridged(address indexed user, uint256 amount, address recipient);
 ```
  Emitted when the USDT fee is bridged to Ethereum.

## Security Considerations
- **Bridge Contract**: Ensure the bridge contract is secure and audited, as it handles cross-chain USDT transfers.
- **USDT Approvals**: Users must approve the`TokenFactory`for 5 USDT, and the contract approves the bridge for the same amount.
- **Owner Privileges**: The owner can update the bridge address and withdraw stuck USDT. Secure the owner’s private key.
- **Reentrancy**: The contract uses standard OpenZeppelin libraries, reducing reentrancy risks, but verify bridge interactions.

## Testing
1. **Test Environment**: Use Base Sepolia testnet.
2. **Test Cases**:
   - Deploy the contract with a mock bridge.
   - Approve and create a token, verifying the new token address and USDT transfer.
   - Check events and bridged fees.
   - Test owner functions (`setBridgeAddress`,`withdrawStuckUSDT`).
3. **Tools**: Hardhat, Foundry, or Mocha/Chai.

## Notes
- **Bridge Placeholder**: The`IBridge`interface is a placeholder. Replace it with the actual bridge contract (e.g., LayerZero, Chainlink CCIP) and ensure compatibility.
- **USDT Address**: Verify the USDT address on Base, as it may differ.
- **Decimals**: USDT uses 6 decimals; created tokens use 18 decimals (standard ERC20).
- **Gas Costs**: Monitor gas costs on Base, especially for cross-chain bridging.

## License
MIT License

---
For issues or contributions, please open a pull request or contact the repository maintainer.
