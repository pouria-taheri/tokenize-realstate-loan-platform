

# Tokenized Real Estate Loan Platform 🏠💸

## Overview

The **Tokenized Real Estate Loan Platform** is a decentralized application (DApp) on Ethereum that transforms real estate investment and lending. It enables users to:

- 🏘️ Tokenize real estate assets as **ERC-721 (NFTs)** or **ERC-20 (fractional shares)**
- 💵 Borrow or lend funds using tokenized assets as **collateral**
- 🔐 Participate in a **transparent**, **secure**, and **DeFi-integrated** ecosystem

This platform enhances **liquidity**, **democratizes** access to real estate markets, and leverages blockchain for **trustless transactions**.  
Built with **Solidity** and the **Foundry** framework, it’s designed for developers and investors alike.

---

## Features 🌟

- **Asset Tokenization**: Create digital tokens for whole or fractional real estate ownership  
- **Collateralized Loans**: Use tokens as collateral to borrow funds or lend to earn interest  
- **Smart Contracts**: Secure, audited Solidity contracts for minting, lending, and repayment  
- **DeFi Integration**: Connect with protocols like **Aave** or **Uniswap** for advanced financial operations  
- **Governance (Optional)**: Token-based voting for platform upgrades  
- **User Dashboard (If implemented)**: A web interface for managing tokens and loans

---

## Technologies 🛠️

- **Solidity**: Smart contracts (`^0.8.0`)
- **Foundry**: Framework for development, testing, and deployment (`forge`, `cast`, `anvil`)
- **Ethereum**: Blockchain network (Sepolia testnet, mainnet)
- **OpenZeppelin**: Secure contract libraries (ERC-721, ERC-20)
- **MetaMask**: Wallet for DApp interactions

---

## Getting Started 🚀

### Prerequisites

**Install Rust (required by Foundry):**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

**Install Foundry:**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**Install MetaMask**: [https://metamask.io](https://metamask.io)

**Create Ethereum Account**: With testnet ETH (e.g., from a Sepolia faucet)

**Alchemy/Infura**: API key for Ethereum network access

**Verify Foundry installation:**
```bash
forge --version && cast --version && anvil --version
```

---

## Installation

**Clone the Repository:**
```bash
git clone https://github.com/pouria-taheri/tokenize-realstate-loan-platform.git
cd tokenize-realstate-loan-platform
```

**Install Dependencies:**
```bash
forge install
```
This fetches libraries (e.g., OpenZeppelin) listed in `foundry.toml`.

**Set Up Environment Variables:**

Create a `.env` file:
```
ETH_RPC_URL=https://<network>.infura.io/v3/your_infura_project_id
PRIVATE_KEY=your_wallet_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

Load the variables:
```bash
source .env
```

**Compile Contracts:**
```bash
forge build
```
Outputs artifacts to `out/`.

---

## Usage 📖

### Run Tests

Verify contract functionality:
```bash
forge test
```

For detailed output:
```bash
forge test -vvv
```

Tests in `test/` cover tokenization and lending logic.

### Start a Local Node

Run a local Ethereum node with Anvil:
```bash
anvil
```

This deploys to `http://localhost:8545`.

### Deploy Contracts

Deploy to a testnet (e.g., Sepolia):
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

Check `script/Deploy.s.sol` for deployment logic.  
Deployed addresses are logged to the console.

### Verify Contracts

Verify on Etherscan:
```bash
forge verify-contract --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY <contract_address> src/PropertyToken.sol:PropertyToken
```
Replace `<contract_address>` with the deployed address.

---

## Interact with the DApp

### Command Line

```bash
cast call <contract_address> "functionName()" --rpc-url $ETH_RPC_URL
```



---

## Workflow

1. 🏗️ Mint a property token (e.g., ERC-721)
2. 🔒 Use it as collateral for a loan
3. 💸 Borrow/lend funds
4. ✅ Repay or claim collateral

---


---







## License 📜

This project is licensed under the **MIT License**

Created With :heart:


