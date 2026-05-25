# 🔐 Minimal Account Abstraction (ERC-4337)

> A minimal, educational implementation of an ERC-4337 smart contract wallet on Ethereum, built with Solidity and Foundry.

***

## 📖 Project Overview

This project implements a **minimal ERC-4337 Account Abstraction wallet** — a smart contract that acts as a user's Ethereum account. Instead of a traditional Externally Owned Account (EOA) controlled by a private key, this smart contract wallet enables:

- Arbitrary transaction execution via an owner-controlled interface
- ERC-4337 compliant UserOperation validation
- Prefund payment to the EntryPoint
- Full compatibility with the ERC-4337 bundler/mempool infrastructure

The project is written in Solidity `^0.8.24`, tested with Foundry, and designed to work on Ethereum Mainnet, Sepolia testnet, and a local Anvil chain.

***

## 🧠 Key Concepts

### What is Account Abstraction (ERC-4337)?

Account Abstraction is an Ethereum standard that allows smart contracts to act as first-class accounts — meaning they can initiate transactions, pay gas fees, and define custom validation logic. ERC-4337 achieves this **without any consensus layer changes** by introducing a higher-level transaction system:

| Concept | Description |
|---|---|
| **UserOperation** | A pseudo-transaction object submitted by a user (not a real tx) |
| **Bundler** | An off-chain node that collects UserOperations and submits them in a real tx |
| **EntryPoint** | A singleton smart contract that validates and executes UserOperations |
| **Smart Account** | The user's smart contract wallet (this project's `MinimalAccount`) |
| **Paymaster** | Optional contract that sponsors gas fees on behalf of users |

### How a UserOperation flows

```
User → signs UserOperation
     → Bundler picks it up from the alt mempool
     → Bundler calls EntryPoint.handleOps()
     → EntryPoint calls account.validateUserOp()
     → EntryPoint calls account.execute()
     → Transaction executes on-chain
```

### PackedUserOperation

ERC-4337 v0.7 introduces `PackedUserOperation`, a gas-optimised struct that packs `verificationGasLimit` and `callGasLimit` together into a single `bytes32` field (`accountGasLimits`), and similarly packs `maxPriorityFeePerGas` and `maxFeePerGas` into `gasFees`. This reduces calldata size and lowers gas costs.

### ECDSA Signature Validation

The wallet validates that a UserOperation was authorised by the wallet owner using ECDSA signature recovery. The flow is:

1. Hash the `userOpHash` with EIP-191 prefix via `MessageHashUtils.toEthSignedMessageHash()`
2. Recover the signer address using `ECDSA.recover()`
3. Compare recovered signer against `owner()`
4. Return `SIG_VALIDATION_SUCCESS` (0) or `SIG_VALIDATION_FAILED` (1)

### Prefund Payment

Before executing a UserOperation, the EntryPoint requires the smart account to pay the estimated gas cost upfront. The `_payPrefund()` function sends `missingAccountFunds` ETH back to the EntryPoint to cover this cost.

***

## 📁 Project Structure

```
Account Abstraction/
├── lib/
│   ├── account-abstraction/       # ERC-4337 interfaces & EntryPoint (v0.7.0)
│   ├── forge-std/                 # Foundry standard library
│   └── openzeppelin-contracts/    # OpenZeppelin contracts (v4.9.3)
├── script/
│   ├── DeployMinimial.s.sol       # Deployment script
│   ├── HelperConfig.s.sol         # Network configuration & mock deployment
│   └── SendPackedUserOp.s.sol     # UserOperation builder & signer
├── src/ethereum/
│   └── MinimalAccount.sol         # Core smart wallet contract
├── test/ethereum/
│   └── MinimalAccountTest.t.sol   # Foundry test suite
├── foundry.toml                   # Foundry configuration
└── README.md
```

***

## 📄 Contract Breakdown

### `MinimalAccount.sol`

The core smart wallet contract. Implements `IAccount` from ERC-4337 and `Ownable` from OpenZeppelin.

**Key functions:**

| Function | Access | Description |
|---|---|---|
| `execute(target, value, data)` | EntryPoint or Owner | Executes an arbitrary call to any target address |
| `validateUserOp(userOp, userOpHash, missingFunds)` | EntryPoint only | Validates signature and pays prefund |
| `getEntryPoint()` | Public view | Returns the bound EntryPoint address |

**Modifiers:**
- `requireFromEntryPoint` — restricts to EntryPoint only (used for `validateUserOp`)
- `requireFromEntryPointOrOwner` — allows both EntryPoint and owner EOA (used for `execute`)

**Design notes:**
- The EntryPoint address is set at construction and stored as `immutable` — it cannot be changed
- Ownership is transferred to `networkConfig.account` after deployment via `transferOwnership()`
- `receive()` is implemented to allow the contract to hold ETH for gas prefunding

***

### `HelperConfig.s.sol`

A Foundry script that provides network-specific configuration. Automatically detects the chain and returns the appropriate `NetworkConfig`.

**Supported networks:**

| Network | Chain ID | EntryPoint |
|---|---|---|
| Ethereum Sepolia | 11155111 | `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789` |
| zkSync Sepolia | 300 | `address(0)` — native AA, no EntryPoint |
| Local Anvil | 31337 | Deployed fresh via `new EntryPoint()` |

For local testing, it deploys a real `EntryPoint` contract instance using `vm.prank(ANVIL_DEFAULT_ACCOUNT)` and caches it in `activeNetworkConfig` to avoid redeployment across calls.

***

### `DeployMinimial.s.sol`

Deployment script that:
1. Instantiates `HelperConfig` to get the active network config
2. Deploys `MinimalAccount` with the correct `entryPoint` address
3. Transfers ownership of the account to `networkConfig.account`
4. Returns both `HelperConfig` and `MinimalAccount` instances (used in tests)

***

### `SendPackedUserOp.s.sol`

A utility script/contract for building, signing, and submitting `PackedUserOperation` structs.

**`generatedSignedUserOperation(callData, networkConfig, account)`**
- Fetches the current nonce from the EntryPoint
- Builds an unsigned `PackedUserOperation`
- Computes the `userOpHash` via `EntryPoint.getUserOpHash()`
- Converts to an EIP-191 digest and signs it
- On local Anvil (`chainid == 31337`), uses the hardcoded Anvil default private key
- On other networks, signs with `networkConfig.account`

**Gas parameters used:**

| Parameter | Value |
|---|---|
| `verificationGasLimit` | 300,000 |
| `callGasLimit` | 300,000 |
| `preVerificationGas` | 50,000 |
| `maxPriorityFeePerGas` | 1 gwei |
| `maxFeePerGas` | 2 gwei |

***

### `MinimalAccountTest.t.sol`

Foundry test suite with four test cases covering the full ERC-4337 execution flow.

| Test | What it verifies |
|---|---|
| `testOwnerCanExecute` | Owner EOA can call `execute()` directly |
| `testNotOwnerCannotExecute` | Non-owner reverts with `MinimalAccount__NotFromOwner` |
| `testRecoverSignedOp` | ECDSA recovery from a signed UserOp returns the correct owner |
| `testValidationOfUserOps` | `validateUserOp()` returns `0` (success) when called by EntryPoint |
| `testEntryPointExecuteCommand` | Full end-to-end: EntryPoint processes a UserOp and executes the call |

***

## ⚙️ Setup & Installation

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed (`forge`, `cast`, `anvil`)
- Git

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd "Account Abstraction"
```

### 2. Install dependencies

```bash
forge install eth-infinitism/account-abstraction@v0.7.0 --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v4.9.3 --no-commit
forge install foundry-rs/forge-std --no-commit
```

### 3. Configure remappings

Ensure your `foundry.toml` contains:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "account-abstraction/=lib/account-abstraction/contracts/",
    "forge-std/=lib/forge-std/src/",
    "openzeppelin-contracts/=lib/openzeppelin-contracts/",
]
```

### 4. Build

```bash
forge build
```

### 5. Run Tests

```bash
# Run all tests
forge test -vvv

# Run a specific test
forge test --match-test testEntryPointExecuteCommand -vvv
```

### 6. Deploy locally (Anvil)

```bash
# Start local Anvil chain
anvil

# In another terminal, deploy
forge script script/DeployMinimial.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### 7. Deploy to Sepolia

```bash
forge script script/DeployMinimial.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

***

## 🔑 Important Notes

- **Never expose private keys** — the Anvil default private key (`0xac09...`) is only used in test/local environments
- The wallet requires ETH balance to pay prefund gas — always `vm.deal()` or fund the account before submitting UserOps
- `PackedUserOperation` is an ERC-4337 v0.7 struct — ensure `lib/account-abstraction` is pinned to `v0.7.0`
- OpenZeppelin must be `v4.9.3` — v5.x moved `ReentrancyGuard` and is incompatible with account-abstraction v0.7

***

## 📜 License

MIT