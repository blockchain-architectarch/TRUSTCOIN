// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  Trustcoin (TRUST) — V6.2 MAINNET FINAL
 * @author Architect — BLOCKCHAIN ARCHITECT
 * @notice Deployed: 0x454d106409890a9f336b5710d638d825a743a8a2
 *
 * DEPLOY ORDER:
 * 1. Deploy TrustcoinV6Mainnet (_initialPrice, _oracleAdmin)
 * 2. Deploy EmissionBridgeV6Mainnet (_trustToken = step1)
 * 3. Deploy TaxBridgeV6Mainnet (_trustToken = step1)
 * 4. setEmissionBridge(step2)
 * 5. setTaxBridge(step3)
 *
 * TAX FLOW (V6.2 — no transactional burn in Period 1):
 * PERIOD 1 (months 1-72):
 *   Base 0.5%: 0.25% TaxBridge (frozen until month 73) + 0.25% FUND direct
 *   Panic:     50% FUND direct + 50% TaxBridge (frozen until month 73)
 * PERIOD 2 (month 73+):
 *   Base 0.5%: 0.25% FUND direct + 0.25% TaxBridge
 *   Panic:     50% FUND direct + 50% TaxBridge
 *   TaxBridge distribute() unlocked: 70/20/10
 *
 * FIX v6.1: EmissionBridge (fromExempt) now enforces wallet limit on recipient
 */
contract TrustcoinV6Mainnet is ERC20, Ownable {

    uint256 public constant INITIAL_SUPPLY         = 200_000_000 * 10**18;
    uint256 public constant BURN_TARGET            = 100_000_000 * 10**18;
    uint256 public constant MONTHLY_RELEASE        =   2_777_778 * 10**18;
    uint256 public constant RELEASE_PERIOD         = 30 days;
    uint256 public constant EARLY_LIMIT_DURATION   = 365 days;
    uint256 public constant EARLY_WALLET_LIMIT     =      10_000 * 10**18;
    uint256 public constant STANDARD_WALLET_LIMIT  =   4_000_000 * 10**18;

    address public constant FUND_ADDRESS = 0xaE851e35a6d4dd66D7Fc2aAAe603a2eD744763Af;
    address public constant HOLDERS_POOL = 0x487E0513F6C96814349A7607F427a920cC4A002A;
    address public constant GUARDS_POOL  = 0x31e0712b7b21dce5B5b15b66AD3F60F8ca235c4c;
    address public constant CHARITY_POOL = 0x0bcAb02E1610aD3e61c7A0090cE401b7ad041426;

    address public emissionBridge;
    address public taxBridge;
    address public priceOracle;
    address public oracleAdmin;

    uint128 public basePrice;
    uint128 public currentPrice;
    uint64  public deployTimestamp;
    uint64  public lastReleaseTime;
    uint64  public priceUpdatedAt;
    uint128 public burnedTotal;
    uint64  public monthsReleased;
    bool    public burningStopped;

    mapping(address => uint256) public holderSince;

    event MonthlyReleaseExecuted(uint256 indexed month, uint256 toEmissionBridge, uint256 burned, uint256 ts);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice, address by);
    event BasePriceReset(uint256 oldBase, uint256 newBase);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OracleAdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event EmissionBridgeSet(address indexed bridge);
    event TaxBridgeSet(address indexed bridge);
    event TaxDistributed(address indexed from, uint256 burned, uint256 toFund, uint256 toTaxBridge);
    event BurnComplete(uint256 total, uint256 ts);
    event HolderRegistered(address indexed holder, uint256 timestamp);
    event HolderReset(address indexed holder);

    constructor(uint128 _initialPrice, address _oracleAdmin)
        ERC20("Trustcoin", "TRUST")
        Ownable(msg.sender)
    {
        require(_initialPrice > 0, "Price must be > 0");
        require(_oracleAdmin != address(0), "Zero: oracleAdmin");
        deployTimestamp = uint64(block.timestamp);
        lastReleaseTime = uint64(block.timestamp);
        priceUpdatedAt  = uint64(block.timestamp);
        basePrice       = _initialPrice;
        currentPrice    = _initialPrice;
        oracleAdmin     = _oracleAdmin;
        _mint(address(this), INITIAL_SUPPLY);
    }

    function setEmissionBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Zero: emissionBridge");
        emissionBridge = _bridge;
        emit EmissionBridgeSet(_bridge);
    }

    function setTaxBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Zero: taxBridge");
        taxBridge = _bridge;
        emit TaxBridgeSet(_bridge);
    }

    function setOracleAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Zero: oracleAdmin");
        address old = oracleAdmin;
        oracleAdmin = _admin;
        emit OracleAdminUpdated(old, _admin);
    }

    function setOracleAddress(address _newOracle) external {
        require(msg.sender == owner() || msg.sender == oracleAdmin, "Not authorized");
        address old = priceOracle;
        priceOracle = _newOracle;
        emit OracleUpdated(old, _newOracle);
    }

    function updatePrice(uint128 _newPrice) external {
        require(msg.sender == owner() || msg.sender == priceOracle, "Not authorized");
        require(_newPrice > 0, "Price must be > 0");
        uint128 old  = currentPrice;
        currentPrice = _newPrice;
        priceUpdatedAt = uint64(block.timestamp);
        emit PriceUpdated(old, _newPrice, msg.sender);
    }

    function resetBasePrice() external onlyOwner {
        uint128 old = basePrice;
        basePrice   = currentPrice;
        emit BasePriceReset(old, currentPrice);
    }

    function _dropPercent() internal view returns (uint256) {
        if (currentPrice >= basePrice) return 0;
        unchecked { return ((uint256(basePrice) - uint256(currentPrice)) * 100) / uint256(basePrice); }
    }

    function _panicTax() internal view returns (uint256) {
        uint256 drop = _dropPercent();
        if (drop < 10)  return 0;
        if (drop >= 50) return 5;
        unchecked { return drop / 10; }
    }

    function monthlyRelease() external onlyOwner {
        require(emissionBridge != address(0), "Emission bridge not set");
        require(monthsReleased < 72, "All 72 months released");
        require(block.timestamp >= uint256(lastReleaseTime) + RELEASE_PERIOD, "Too early");
        uint256 available = balanceOf(address(this));
        require(available > 0, "Treasury empty");
        uint256 toRelease        = available < MONTHLY_RELEASE ? available : MONTHLY_RELEASE;
        uint256 toBurn           = toRelease / 2;
        uint256 toEmissionBridge = toRelease - toBurn;
        unchecked { monthsReleased++; }
        lastReleaseTime = uint64(block.timestamp);
        if (toBurn > 0 && !burningStopped) {
            super._update(address(this), address(0), toBurn);
            unchecked { burnedTotal += uint128(toBurn); }
            _checkStop();
        }
        if (toEmissionBridge > 0) { super._update(address(this), emissionBridge, toEmissionBridge); }
        emit MonthlyReleaseExecuted(monthsReleased, toEmissionBridge, toBurn, block.timestamp);
    }

    function _checkStop() internal {
        if (!burningStopped && burnedTotal >= uint128(BURN_TARGET)) {
            burningStopped = true;
            emit BurnComplete(burnedTotal, block.timestamp);
        }
    }

    function _isPeriod1() internal view returns (bool) { return monthsReleased < 72; }

    function _isExempt(address addr) internal view returns (bool) {
        return (addr == address(this) || addr == taxBridge || addr == FUND_ADDRESS ||
                addr == HOLDERS_POOL  || addr == GUARDS_POOL || addr == CHARITY_POOL);
    }

    function _walletLimit() internal view returns (uint256) {
        unchecked {
            if (block.timestamp < uint256(deployTimestamp) + EARLY_LIMIT_DURATION) return EARLY_WALLET_LIMIT;
        }
        return STANDARD_WALLET_LIMIT;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0)) { super._update(from, to, amount); return; }
        bool toExempt   = _isExempt(to);
        bool fromExempt = _isExempt(from);
        if (!toExempt && holderSince[to] == 0) { holderSince[to] = block.timestamp; emit HolderRegistered(to, block.timestamp); }
        if (!fromExempt && from != emissionBridge && holderSince[from] != 0) { delete holderSince[from]; emit HolderReset(from); }
        if (taxBridge == address(0) || emissionBridge == address(0)) { super._update(from, to, amount); return; }
        if (fromExempt) {
            if (!toExempt) { require(balanceOf(to) + amount <= _walletLimit(), "Exceeds wallet limit"); }
            super._update(from, to, amount); return;
        }
        if (!toExempt) { require(balanceOf(to) + amount <= _walletLimit(), "Exceeds wallet limit"); }
        bool period1 = _isPeriod1();
        if (period1 && !toExempt && !fromExempt) { require(amount >= 1_000 * 10**18, "Min 1000 tokens in Period 1"); }
        uint256 panicRate = _panicTax();
        uint256 totalBurn; uint256 totalFund; uint256 totalTaxBridge;
        unchecked {
            uint256 baseFund = (amount * 25) / 10000;
            uint256 baseBridge = (amount * 25) / 10000;
            uint256 panicFund; uint256 panicBridge;
            if (panicRate > 0) {
                uint256 panicTotal = (amount * panicRate) / 100;
                panicFund   = panicTotal / 2;
                panicBridge = panicTotal - panicFund;
            }
            totalBurn      = 0;
            totalFund      = baseFund + panicFund;
            totalTaxBridge = baseBridge + panicBridge;
        }
        uint256 sendAmount = amount - totalBurn - totalFund - totalTaxBridge;
        if (totalFund > 0) { super._update(from, FUND_ADDRESS, totalFund); }
        if (totalTaxBridge > 0) { super._update(from, taxBridge, totalTaxBridge); }
        super._update(from, to, sendAmount);
        emit TaxDistributed(from, totalBurn, totalFund, totalTaxBridge);
    }

    function getHolderDay(address holder) external view returns (uint256) {
        if (holderSince[holder] == 0) return 0;
        unchecked { return (block.timestamp - holderSince[holder]) / 1 days + 1; }
    }

    function isActiveHolder(address holder) external view returns (bool) {
        return holderSince[holder] != 0 && balanceOf(holder) > 0;
    }

    function nextReleaseIn() external view returns (uint256 daysLeft) {
        uint256 next = uint256(lastReleaseTime) + RELEASE_PERIOD;
        if (block.timestamp >= next) return 0;
        return (next - block.timestamp) / 1 days;
    }

    function burnProgress() external view returns (uint256 currentSupply, uint256 burned, uint256 burnedPercent, uint256 remaining, bool stopped) {
        currentSupply = totalSupply(); burned = burnedTotal;
        unchecked { burnedPercent = (uint256(burnedTotal) * 100) / BURN_TARGET; }
        remaining = burnedTotal >= uint128(BURN_TARGET) ? 0 : BURN_TARGET - burnedTotal;
        stopped = burningStopped;
    }

    function version() external pure returns (string memory) {
        return "TrustcoinV6.2 MAINNET — no release pause — EmissionBridge buffer";
    }
}
