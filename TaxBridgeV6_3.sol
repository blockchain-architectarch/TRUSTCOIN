// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  TaxBridge — V6.3 MAINNET
 * @author Architect — BLOCKCHAIN ARCHITECT
 * @notice Deployed: 0x59ab99534d5b830b4db04f17f5bf546556dc6233
 *
 * PERIOD 1 (months 1-72): Accumulates 0.25% base + 50% panic tax. distribute() LOCKED.
 * PERIOD 2 (month 73+):   distribute() UNLOCKED every 90 days.
 *
 * DISTRIBUTION (immutable):
 *   70% → CumulativeLoyaltyVault (holders claim)
 *   20% → GUARDS_VAULT (Trezor #3)
 *   10% → CHARITY_VAULT (Trezor #4)
 *
 * VAULT MIGRATION: Two-step with 365-day timelock.
 *   1. proposeDistributor() — propose new Vault (~Month 60)
 *   2. applyDistributor()   — apply after 365 days (~Month 72)
 *   3. cancelProposal()     — cancel if wrong address proposed
 */

interface ITrustcoinV6 {
    function monthsReleased() external view returns (uint64);
}

contract TaxBridgeV6_3Mainnet is Ownable {

    uint256 public constant HOLDERS_SHARE       = 7000; // 70%
    uint256 public constant GUARDS_SHARE        = 2000; // 20%
    uint256 public constant CHARITY_SHARE       = 1000; // 10%
    uint256 public constant DISTRIBUTION_PERIOD = 90 days;
    uint256 public constant TIMELOCK_DURATION   = 365 days;
    uint64  public constant UNLOCK_MONTH        = 72;

    address public constant GUARDS_VAULT  = 0x31e0712b7b21dce5B5b15b66AD3F60F8ca235c4c;
    address public constant CHARITY_VAULT = 0x0bcAb02E1610aD3e61c7A0090cE401b7ad041426;

    ITrustcoinV6 public trustToken;

    address public holdersDistributor;
    address public pendingDistributor;
    uint256 public timelockEnd;
    uint256 public lastDistribution;
    uint256 public totalDistributed;
    uint256 public distributionCount;

    event Distributed(uint256 indexed count, uint256 total, uint256 toHolders, uint256 toGuards, uint256 toCharity, uint256 ts);
    event DistributorProposed(address indexed proposed, uint256 timelockEnd, uint256 ts);
    event DistributorApplied(address indexed oldDistributor, address indexed newDistributor, uint256 ts);
    event DistributorProposalCancelled(address indexed cancelled, uint256 ts);

    constructor(address _trustToken) Ownable(msg.sender) {
        require(_trustToken != address(0), "Zero: trustToken");
        trustToken       = ITrustcoinV6(_trustToken);
        lastDistribution = block.timestamp;
    }

    function proposeDistributor(address _distributor) external onlyOwner {
        require(_distributor != address(0), "Zero: distributor");
        require(_distributor != holdersDistributor, "Already active");
        pendingDistributor = _distributor;
        timelockEnd        = block.timestamp + TIMELOCK_DURATION;
        emit DistributorProposed(_distributor, timelockEnd, block.timestamp);
    }

    function applyDistributor() external {
        require(pendingDistributor != address(0), "Nothing pending");
        require(block.timestamp >= timelockEnd,   "Timelock not expired");
        address old        = holdersDistributor;
        holdersDistributor = pendingDistributor;
        pendingDistributor = address(0);
        timelockEnd        = 0;
        emit DistributorApplied(old, holdersDistributor, block.timestamp);
    }

    function cancelProposal() external onlyOwner {
        require(pendingDistributor != address(0), "Nothing to cancel");
        require(block.timestamp < timelockEnd,    "Timelock expired");
        address cancelled  = pendingDistributor;
        pendingDistributor = address(0);
        timelockEnd        = 0;
        emit DistributorProposalCancelled(cancelled, block.timestamp);
    }

    function distribute() external {
        require(holdersDistributor != address(0),            "Distributor not set");
        require(trustToken.monthsReleased() >= UNLOCK_MONTH, "Locked until month 73");
        require(block.timestamp >= lastDistribution + DISTRIBUTION_PERIOD, "Too early: wait 90 days");
        uint256 balance = IERC20(address(trustToken)).balanceOf(address(this));
        require(balance > 0, "Bridge is empty");
        uint256 toHolders = (balance * HOLDERS_SHARE) / 10000;
        uint256 toGuards  = (balance * GUARDS_SHARE)  / 10000;
        uint256 toCharity = balance - toHolders - toGuards;
        lastDistribution = block.timestamp;
        unchecked { totalDistributed += balance; distributionCount++; }
        require(IERC20(address(trustToken)).transfer(holdersDistributor, toHolders), "Holders transfer failed");
        require(IERC20(address(trustToken)).transfer(GUARDS_VAULT, toGuards),        "Guards transfer failed");
        require(IERC20(address(trustToken)).transfer(CHARITY_VAULT, toCharity),      "Charity transfer failed");
        emit Distributed(distributionCount, balance, toHolders, toGuards, toCharity, block.timestamp);
    }

    function isUnlocked() external view returns (bool) { return trustToken.monthsReleased() >= UNLOCK_MONTH; }

    function bridgeBalance() external view returns (uint256) { return IERC20(address(trustToken)).balanceOf(address(this)); }

    function previewDistribution() external view returns (uint256 total, uint256 toHolders, uint256 toGuards, uint256 toCharity) {
        total     = IERC20(address(trustToken)).balanceOf(address(this));
        toHolders = (total * HOLDERS_SHARE) / 10000;
        toGuards  = (total * GUARDS_SHARE)  / 10000;
        toCharity = total - toHolders - toGuards;
    }

    function version() external pure returns (string memory) {
        return "TaxBridge V6.3 MAINNET — 365day timelock migration — 90day distribute";
    }
}
