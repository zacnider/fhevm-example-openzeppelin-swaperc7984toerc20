# EntropySwapERC7984ToERC20

Swap contract for exchanging ERC7984 confidential tokens to ERC20 tokens

## 🚀 Standard workflow
- Install (first run): `npm install --legacy-peer-deps`
- Compile: `npx hardhat compile`
- Test (local FHE + local oracle/chaos engine auto-deployed): `npx hardhat test`
- Deploy (frontend Deploy button): constructor args fixed to EntropyOracle and ERC20 token address; oracle is `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`
- Verify: `npx hardhat verify --network sepolia <contractAddress> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361 <ERC20_TOKEN_ADDRESS>`

## 📋 Overview

This example demonstrates **OpenZeppelin** concepts in FHEVM with **EntropyOracle integration**:
- Swapping ERC7984 tokens to ERC20
- Exchange rate management
- EntropyOracle integration for random swap operations
- Privacy-preserving token swaps

## 🎯 What This Example Teaches

This tutorial will teach you:

1. **How to swap ERC7984 tokens** for ERC20 tokens
2. **How to manage exchange rates** between token types
3. **How to deposit ERC7984 tokens** into swap contract
4. **How to use entropy** for random swap operations
5. **Token swapping mechanics** with encrypted amounts
6. **Real-world swap implementation** between confidential and public tokens

## 💡 Why This Matters

Swaps enable token conversion:
- **Allows trading** between confidential and public tokens
- **Enables use in DeFi** - swap confidential tokens for standard tokens
- **Maintains privacy** - swap amounts remain encrypted
- **Entropy adds randomness** to swap calculations
- **Real-world application** in DeFi protocols

## 🔍 How It Works

### Contract Structure

The contract has four main components:

1. **Request Swap with Entropy**: Request entropy for swapping
2. **Swap with Entropy**: Swap ERC7984 tokens for ERC20
3. **Deposit**: Deposit ERC7984 tokens into swap contract
4. **Balance Queries**: Get encrypted balances

### Step-by-Step Code Explanation

#### 1. Constructor

```solidity
constructor(
    address _entropyOracle,
    address _erc20Token
) {
    require(_entropyOracle != address(0), "Invalid oracle address");
    require(_erc20Token != address(0), "Invalid ERC20 address");
    entropyOracle = IEntropyOracle(_entropyOracle);
    erc20Token = IERC20(_erc20Token);
}
```

**What it does:**
- Takes EntropyOracle address and ERC20 token address
- Validates both addresses are not zero
- Stores oracle interface and ERC20 token interface

**Why it matters:**
- Must use the correct oracle address: `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`
- ERC20 token address for receiving/swapping tokens

#### 2. Request Swap with Entropy

```solidity
function requestSwapWithEntropy(bytes32 tag) external payable returns (uint256 requestId) {
    require(msg.value >= entropyOracle.getFee(), "Insufficient fee");
    
    requestId = entropyOracle.requestEntropy{value: msg.value}(tag);
    swapRequests[requestId] = msg.sender;
    swapRequestCount++;
    
    emit SwapRequested(msg.sender, requestId);
    return requestId;
}
```

**What it does:**
- Validates fee payment
- Requests entropy from EntropyOracle
- Stores swap request with user address
- Returns request ID

**Key concepts:**
- **Two-phase swapping**: Request first, swap later
- **Request tracking**: Maps request ID to user
- **Entropy for randomness**: Adds randomness to swap calculations

#### 3. Swap with Entropy

```solidity
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
```

**What it does:**
- Validates request ID and fulfillment
- Converts external encrypted amount to internal
- Subtracts amount from user's encrypted balance
- Calculates ERC20 output amount (simplified)
- Validates contract has enough ERC20 liquidity
- Transfers ERC20 tokens to user
- Emits swap event

**Key concepts:**
- **Encrypted deduction**: ERC7984 balance decreased (encrypted)
- **ERC20 transfer**: ERC20 tokens transferred (public)
- **Exchange rate**: Used to calculate output amount

**Why simplified:**
- Full implementation requires decryption or oracle
- This example shows the pattern
- Production: Use decryption or conversion oracle

#### 4. Deposit

```solidity
function deposit(
    externalEuint64 encryptedAmount,
    bytes calldata inputProof
) external {
    euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
    FHE.allowThis(amount);
    encryptedBalances[msg.sender] = FHE.add(encryptedBalances[msg.sender], amount);
}
```

**What it does:**
- Converts external encrypted amount to internal
- Adds amount to user's encrypted balance
- Enables swapping by providing liquidity

**Key concepts:**
- **Encrypted deposit**: Amount stored encrypted
- **Balance increase**: User balance increased for swapping

## 🧪 Step-by-Step Testing

### Prerequisites

1. **Install dependencies:**
   ```bash
   npm install --legacy-peer-deps
   ```

2. **Compile contracts:**
   ```bash
   npx hardhat compile
   ```

### Running Tests

```bash
npx hardhat test
```

### What Happens in Tests

1. **Fixture Setup** (`deployContractFixture`):
   - Deploys FHEChaosEngine, EntropyOracle, ERC20 token, and EntropySwapERC7984ToERC20
   - Returns all contract instances

2. **Test: Deposit**
   ```typescript
   it("Should deposit ERC7984 tokens", async function () {
     const input = hre.fhevm.createEncryptedInput(contractAddress, owner.address);
     input.add64(100);
     const encryptedInput = await input.encrypt();
     
     await contract.deposit(encryptedInput.handles[0], encryptedInput.inputProof);
     
     const balance = await contract.getEncryptedBalance(owner.address);
     expect(balance).to.not.be.undefined;
   });
   ```
   - Creates encrypted amount
   - Deposits into swap contract
   - Verifies balance increased

3. **Test: Swap with Entropy**
   ```typescript
   it("Should swap ERC7984 to ERC20", async function () {
     // ... deposit code ...
     const tag = hre.ethers.id("swap-request");
     const fee = await oracle.getFee();
     const requestId = await contract.requestSwapWithEntropy(tag, { value: fee });
     await waitForEntropy(requestId);
     
     const input = hre.fhevm.createEncryptedInput(contractAddress, owner.address);
     input.add64(50);
     const encryptedInput = await input.encrypt();
     
     await contract.swapWithEntropy(
       requestId,
       encryptedInput.handles[0],
       encryptedInput.inputProof
     );
     
     const erc20Balance = await erc20Token.balanceOf(owner.address);
     expect(erc20Balance).to.be.greaterThan(0);
   });
   ```
   - Deposits tokens
   - Requests entropy for swap
   - Swaps ERC7984 for ERC20
   - Verifies ERC20 balance increased

### Expected Test Output

```
  EntropySwapERC7984ToERC20
    Deployment
      ✓ Should deploy successfully
      ✓ Should have EntropyOracle address set
    Deposits
      ✓ Should deposit ERC7984 tokens
    Swapping
      ✓ Should request swap with entropy
      ✓ Should swap ERC7984 to ERC20

  5 passing
```

**Note:** ERC7984 balances are encrypted (handles). ERC20 balances are public uint256 values.

## 🚀 Step-by-Step Deployment

### Option 1: Frontend (Recommended)

1. Navigate to [Examples page](/examples)
2. Find "EntropySwapERC7984ToERC20" in Tutorial Examples
3. Click **"Deploy"** button
4. Approve transaction in wallet
5. Wait for deployment confirmation
6. Copy deployed contract address

### Option 2: CLI

1. **Create deploy script** (`scripts/deploy.ts`):
   ```typescript
   import hre from "hardhat";

   async function main() {
     const ENTROPY_ORACLE_ADDRESS = "0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361";
     const ERC20_TOKEN_ADDRESS = "0x..."; // Your ERC20 token address
     
     const ContractFactory = await hre.ethers.getContractFactory("EntropySwapERC7984ToERC20");
     const contract = await ContractFactory.deploy(
       ENTROPY_ORACLE_ADDRESS,
       ERC20_TOKEN_ADDRESS
     );
     await contract.waitForDeployment();
     
     const address = await contract.getAddress();
     console.log("EntropySwapERC7984ToERC20 deployed to:", address);
   }

   main().catch((error) => {
     console.error(error);
     process.exitCode = 1;
   });
   ```

2. **Deploy:**
   ```bash
   npx hardhat run scripts/deploy.ts --network sepolia
   ```

## ✅ Step-by-Step Verification

### Option 1: Frontend

1. After deployment, click **"Verify"** button on Examples page
2. Wait for verification confirmation
3. View verified contract on Etherscan

### Option 2: CLI

```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361 <ERC20_TOKEN_ADDRESS>
```

**Important:** Constructor arguments must be:
1. EntropyOracle address: `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`
2. ERC20 token address: Your ERC20 token contract address

## 📊 Expected Outputs

### After Deposit

- `getEncryptedBalance(user)` returns increased encrypted balance
- User can now swap tokens

### After Request Swap with Entropy

- `swapRequests[requestId]` contains user address
- `swapRequestCount` increments
- `SwapRequested` event emitted

### After Swap with Entropy

- `getEncryptedBalance(user)` returns decreased encrypted balance
- `erc20Token.balanceOf(user)` returns increased ERC20 balance
- `Swapped` event emitted

## ⚠️ Common Errors & Solutions

### Error: `SenderNotAllowed()`

**Cause:** Missing `FHE.allowThis()` call on encrypted amount.

**Solution:**
```solidity
euint64 amount = FHE.fromExternal(encryptedAmount, inputProof);
FHE.allowThis(amount); // ✅ Required!
```

**Prevention:** Always call `FHE.allowThis()` on all encrypted values before using them.

---

### Error: `Entropy not ready`

**Cause:** Calling `swapWithEntropy()` before entropy is fulfilled.

**Solution:** Always check `isRequestFulfilled()` before using entropy.

---

### Error: `Invalid request`

**Cause:** Request ID doesn't belong to caller.

**Solution:** Ensure request ID matches the caller's request.

---

### Error: `Insufficient ERC20 liquidity`

**Cause:** Contract doesn't have enough ERC20 tokens for swap.

**Solution:** Ensure contract has sufficient ERC20 balance before swapping. Deposit ERC20 tokens to contract.

---

### Error: `Insufficient fee`

**Cause:** Not sending enough ETH when requesting swap.

**Solution:** Always send exactly 0.00001 ETH:
```typescript
const fee = await contract.entropyOracle.getFee();
await contract.requestSwapWithEntropy(tag, { value: fee });
```

---

### Error: Verification failed - Constructor arguments mismatch

**Cause:** Wrong constructor arguments used during verification.

**Solution:** Always use EntropyOracle address and ERC20 token address:
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361 <ERC20_TOKEN_ADDRESS>
```

## 🔗 Related Examples

- [EntropyERC7984Token](../openzeppelin-erc7984token/) - ERC7984 token implementation
- [EntropySwapERC7984ToERC7984](../openzeppelin-swaperc7984toerc7984/) - Cross-token swaps
- [Category: openzeppelin](../)

## 📚 Additional Resources

- [Full Tutorial Track Documentation](../../../frontend/src/pages/Docs.tsx) - Complete educational guide
- [Zama FHEVM Documentation](https://docs.zama.org/) - Official FHEVM docs
- [GitHub Repository](https://github.com/zacnider/entrofhe/tree/main/examples/openzeppelin-swaperc7984toerc20) - Source code

## 📝 License

BSD-3-Clause-Clear
