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
