
## Real Estate Tokenization SMART CONTRACT


This project involves the development of a blockchain-based system for tokenizing real estate properties using Ethereum smart contracts. The core functionality allows fractional ownership, rent management, and KYC verification for participants. Below is a breakdown of each key component:

#### 1. **RealEstateToken.sol**:

-   **Inheritance**: Extends several OpenZeppelin contracts:
    -   `ERC721`: Standard for non-fungible tokens.
    -   `ReentrancyGuard`: Prevents reentrancy attacks.
    -   `AccessControl`: Provides role-based access control.
    -   `Pausable`: Allows pausing of contract functions.
-   **Roles**:
    -   `PROPERTY_MANAGER`: Manages property-specific operations.
-   **Mappings**:
    -   `kycApproved`: Tracks KYC-approved users.
    -   `rentPeriods`: Stores rent details for each period.
    -   `tokenPrices`: Maintains the price of each fractional token.
-   **Constructor**:
    -   Initializes property details, assigns roles, and pre-mints fractional ownership tokens (NFTs) for the property.
-   **KYC Management**: Functions for setting and verifying KYC status.
-   **Token Price and Transfer**:
    -   Price setting and batch purchase of tokens.
    -   Custom `_transfer` and `_safeTransfer` methods ensuring KYC compliance.
-   **Rent Management**:
    -   Rent payment and distribution among token holders.
    -   Rent periods are tracked, and maintenance fees are deducted.
-   **Maintenance and Document Management**:
    -   Handles maintenance reserve funds and updates to property documents.

#### 2. **IRealEstateToken.sol**:

-   **Interface Definition**:
    -   Defines `PropertyDetails` and `RentPeriod` structs.
    -   Provides function signatures for retrieving property and rent details.

#### 3. **RealEstateDeployer.sol**:

-   **Role Management**:
    -   `VERIFIER_ROLE` and `LEGAL_ADMIN_ROLE` for handling property verification and legal oversight.
-   **Property Verification**:
    -   Maintains a registry of verified properties.
    -   Emits events upon tokenization and verification of properties.
-   **Deployer Role**:
    -   The contract deployer is granted the default admin role.

### Key Features:

-   **Fractional Ownership**: Properties are divided into multiple shares (NFTs), enabling fractional ownership.
-   **KYC Compliance**: Ensures that only verified users can interact with certain functions, enhancing security.
-   **Rent Management**: Automates rent collection and distribution, providing passive income to token holders.
-   **Role-Based Access Control**: Granular control over who can execute specific functions, ensuring proper management and security.
-   **Property Verification**: Adds a layer of trust by allowing verification of properties before tokenization.

### Benefits:

-   **Accessibility**: Lowers the barrier to real estate investment by enabling fractional ownership.
-   **Transparency**: Blockchain-based operations provide transparency in transactions and ownership.
-   **Automation**: Automates processes like rent distribution and maintenance fee management.






## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

 ##### Note: You should installed WSL before work with foundry.

## Documentation

https://book.getfoundry.sh/

## Usage

### Instalation
```shell
curl -L https://foundry.paradigm.xyz | bash
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/DeployRealEstateToken.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
