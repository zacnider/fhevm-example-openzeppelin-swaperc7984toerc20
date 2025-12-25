# SwapERC7984ToERC20

Learn how to use OpenZeppelin ERC7984 confidential tokens

## 🎓 What You'll Learn

This example teaches you how to use FHEVM to build privacy-preserving smart contracts. You'll learn step-by-step how to implement encrypted operations, manage permissions, and work with encrypted data.

## 🚀 Quick Start

1. **Clone this repository:**
   ```bash
   git clone https://github.com/zacnider/fhevm-example-openzeppelin-swaperc7984toerc20.git
   cd fhevm-example-openzeppelin-swaperc7984toerc20
   ```

2. **Install dependencies:**
   ```bash
   npm install --legacy-peer-deps
   ```

3. **Setup environment:**
   ```bash
   npm run setup
   ```
   Then edit `.env` file with your credentials:
   - `SEPOLIA_RPC_URL` - Your Sepolia RPC endpoint
   - `PRIVATE_KEY` - Your wallet private key (for deployment)
   - `ETHERSCAN_API_KEY` - Your Etherscan API key (for verification)

4. **Compile contracts:**
   ```bash
   npm run compile
   ```

5. **Run tests:**
   ```bash
   npm test
   ```

6. **Deploy to Sepolia:**
   ```bash
   npm run deploy:sepolia
   ```

7. **Verify contract (after deployment):**
   ```bash
   npm run verify <CONTRACT_ADDRESS>
   ```

**Alternative:** Use the [Examples page](https://entrofhe.vercel.app/examples) for browser-based deployment and verification.

---

## 📚 Overview

@title EntropySwapERC7984ToERC20
@notice Swap contract for exchanging ERC7984 confidential tokens to ERC20 tokens
@dev Demonstrates swapping confidential tokens to standard tokens
In this example, you will learn:
- Swapping ERC7984 tokens to ERC20
- Exchange rate management
- encrypted randomness integration for random swap operations

@notice Request entropy for swap with randomness
@param tag Unique tag for entropy request
@return requestId Entropy request ID

@notice Swap ERC7984 tokens to ERC20 using entropy
@param requestId Entropy request ID
@param encryptedAmount Encrypted amount to swap
@param inputProof Input proof for encrypted amount

@notice Deposit ERC7984 tokens
@param encryptedAmount Encrypted amount to deposit
@param inputProof Input proof for encrypted amount

@notice Get encrypted balance
@param account Address to query
@return Encrypted balance

@notice Get encrypted randomness address
@return encrypted randomness contract address



## 🔐 Learn Zama FHEVM Through This Example

This example teaches you how to use the following **Zama FHEVM** features:

### What You'll Learn About

- **ZamaEthereumConfig**: Inherits from Zama's network configuration
  ```solidity
  contract MyContract is ZamaEthereumConfig {
      // Inherits network-specific FHEVM configuration
  }
  ```

- **FHE Operations**: Uses Zama's FHE library for encrypted operations
  - `FHE operations` - Zama FHEVM operation
  - `FHE.allowThis()` - Zama FHEVM operation
  - `FHE.allow()` - Zama FHEVM operation

- **Encrypted Types**: Uses Zama's encrypted integer types
  - `euint64` - 64-bit encrypted unsigned integer
  - `externalEuint64` - External encrypted value from user

- **Access Control**: Uses Zama's permission system
  - `FHE.allowThis()` - Allow contract to use encrypted values
  - `FHE.allow()` - Allow specific user to decrypt
  - `FHE.allowTransient()` - Temporary permission for single operation
  - `FHE.fromExternal()` - Convert external encrypted values to internal

### Zama FHEVM Imports

```solidity
// Zama FHEVM Core Library - FHE operations and encrypted types
import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";

// Zama Network Configuration - Provides network-specific settings
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
```

### Zama FHEVM Code Example

```solidity
// Using Zama FHEVM with OpenZeppelin confidential contracts
euint64 encryptedAmount = FHE.fromExternal(encryptedInput, inputProof);
FHE.allowThis(encryptedAmount);

// Zama FHEVM enables encrypted token operations
// All amounts remain encrypted during transfers
```

### FHEVM Concepts You'll Learn

1. **OpenZeppelin Integration**: Learn how to use Zama FHEVM for openzeppelin integration
2. **ERC7984 Confidential Tokens**: Learn how to use Zama FHEVM for erc7984 confidential tokens
3. **FHE Operations**: Learn how to use Zama FHEVM for fhe operations

### Learn More About Zama FHEVM

- 📚 [Zama FHEVM Documentation](https://docs.zama.org/protocol)
- 🎓 [Zama Developer Hub](https://www.zama.org/developer-hub)
- 💻 [Zama FHEVM GitHub](https://github.com/zama-ai/fhevm)



## 🔍 Contract Code

```solidity
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IEntropyOracle.sol";

/**
 * @title EntropySwapERC7984ToERC20
 * @notice Swap contract for exchanging ERC7984 confidential tokens to ERC20 tokens
 * @dev Demonstrates swapping confidential tokens to standard tokens
 * 
 * This example shows:
 * - Swapping ERC7984 tokens to ERC20
 * - Exchange rate management
 * - EntropyOracle integration for random swap operations
 */
contract EntropySwapERC7984ToERC20 is ZamaEthereumConfig {
    IEntropyOracle public entropyOracle;
    IERC20 public erc20Token;
    
    // Encrypted balances
    mapping(address => euint64) private encryptedBalances;
    
    // Exchange rate (1 ERC7984 = rate ERC20)
    uint256 public exchangeRate = 1; // 1:1 by default
    
    // Track entropy requests
    mapping(uint256 => address) public swapRequests;
    uint256 public swapRequestCount;
    
    event Swapped(address indexed user, bytes encryptedAmount, uint256 erc20Amount);
    event SwapRequested(address indexed user, uint256 indexed requestId);
    
    constructor(
        address _entropyOracle,
        address _erc20Token
    ) {
        require(_entropyOracle != address(0), "Invalid oracle address");
        require(_erc20Token != address(0), "Invalid ERC20 address");
        entropyOracle = IEntropyOracle(_entropyOracle);
        erc20Token = IERC20(_erc20Token);
    }
    
    /**
     * @notice Request entropy for swap with randomness
     * @param tag Unique tag for entropy request
     * @return requestId Entropy request ID
     */
    function requestSwapWithEntropy(bytes32 tag) external payable returns (uint256 requestId) {
        require(msg.value >= entropyOracle.getFee(), "Insufficient fee");
        
        requestId = entropyOracle.requestEntropy{value: msg.value}(tag);
        swapRequests[requestId] = msg.sender;
        swapRequestCount++;
        
        emit SwapRequested(msg.sender, requestId);
        return requestId;
    }
    
    /**
     * @notice Swap ERC7984 tokens to ERC20 using entropy
     * @param requestId Entropy request ID
     * @param encryptedAmount Encrypted amount to swap
     * @param inputProof Input proof for encrypted amount
     */
    function swapWithEntropy(
        uint256 requestId,
        externalEuint64 encryptedAmount,
        bytes calldata inputProof
    ) external {
        require(entropyOracle.isRequestFulfilled(requestId), "Entropy not ready");
        require(swapRequests[requestId] == msg.sender, "Invalid request");
        
        euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
        FHE.allowThis(amount);
        
        // Deduct from encrypted balance
        encryptedBalances[msg.sender] = FHE.sub(encryptedBalances[msg.sender], amount);
        
        // Calculate ERC20 amount (simplified - in real implementation, decrypt or use oracle)
        uint256 erc20Amount = 1000 * exchangeRate; // Placeholder
        
        require(erc20Token.balanceOf(address(this)) >= erc20Amount, "Insufficient ERC20 liquidity");
        erc20Token.transfer(msg.sender, erc20Amount);
        
        delete swapRequests[requestId];
        
        emit Swapped(msg.sender, abi.encode(encryptedAmount), erc20Amount);
    }
    
    /**
     * @notice Deposit ERC7984 tokens
     * @param encryptedAmount Encrypted amount to deposit
     * @param inputProof Input proof for encrypted amount
     */
    function deposit(
        externalEuint64 encryptedAmount,
        bytes calldata inputProof
    ) external {
        euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
        FHE.allowThis(amount);
        encryptedBalances[msg.sender] = FHE.add(encryptedBalances[msg.sender], amount);
    }
    
    /**
     * @notice Get encrypted balance
     * @param account Address to query
     * @return Encrypted balance
     */
    function getEncryptedBalance(address account) external view returns (euint64) {
        return encryptedBalances[account];
    }
    
    /**
     * @notice Get EntropyOracle address
     * @return EntropyOracle contract address
     */
    function getEntropyOracle() external view returns (address) {
        return address(entropyOracle);
    }
}

```

## 🧪 Tests

See [test file](./test/SwapERC7984ToERC20.test.ts) for comprehensive test coverage.

```bash
npm test
```


## 📚 Category

**openzeppelin**



## 🔗 Related Examples

- [All openzeppelin examples](https://github.com/zacnider/entrofhe/tree/main/examples)

## 📝 License

BSD-3-Clause-Clear
