# TRUSTCOIN ($TRUST) — Holdership Growth Coefficient G

**Multiplier applied to your balance share for every 30 days of continuous holding**

- Formula: G(n) = 10.00 − 0.138 × (n − 1)
- Month 1: ×10.00 → Month 72: ×0.20
- Any outgoing transaction resets G to zero **permanently**
- G is calculated off-chain at the Month 72 snapshot

---

| Month | Coefficient G | Month | Coefficient G | Month | Coefficient G |
|------:|--------------|------:|--------------|------:|--------------|
|  1 | ×10.00 | 25 | ×6.69 | 49 | ×3.38 |
|  2 | ×9.86 | 26 | ×6.55 | 50 | ×3.24 |
|  3 | ×9.72 | 27 | ×6.41 | 51 | ×3.10 |
|  4 | ×9.59 | 28 | ×6.27 | 52 | ×2.96 |
|  5 | ×9.45 | 29 | ×6.14 | 53 | ×2.82 |
|  6 | ×9.31 | 30 | ×6.00 | 54 | ×2.69 |
|  7 | ×9.17 | 31 | ×5.86 | 55 | ×2.55 |
|  8 | ×9.03 | 32 | ×5.72 | 56 | ×2.41 |
|  9 | ×8.90 | 33 | ×5.58 | 57 | ×2.27 |
| 10 | ×8.76 | 34 | ×5.45 | 58 | ×2.13 |
| 11 | ×8.62 | 35 | ×5.31 | 59 | ×2.00 |
| 12 | ×8.48 | 36 | ×5.17 | 60 | ×1.86 |
| 13 | ×8.34 | 37 | ×5.03 | 61 | ×1.72 |
| 14 | ×8.21 | 38 | ×4.89 | 62 | ×1.58 |
| 15 | ×8.07 | 39 | ×4.76 | 63 | ×1.44 |
| 16 | ×7.93 | 40 | ×4.62 | 64 | ×1.31 |
| 17 | ×7.79 | 41 | ×4.48 | 65 | ×1.17 |
| 18 | ×7.65 | 42 | ×4.34 | 66 | ×1.03 |
| 19 | ×7.52 | 43 | ×4.20 | 67 | ×0.89 |
| 20 | ×7.38 | 44 | ×4.07 | 68 | ×0.75 |
| 21 | ×7.24 | 45 | ×3.93 | 69 | ×0.62 |
| 22 | ×7.10 | 46 | ×3.79 | 70 | ×0.48 |
| 23 | ×6.96 | 47 | ×3.65 | 71 | ×0.34 |
| 24 | ×6.83 | 48 | ×3.51 | 72 | ×0.20 |

---

## Key Values

| Milestone | G Value |
|-----------|---------|
| Month 1 (Day 1) | ×10.00 |
| Month 12 (Year 1 end) | ×8.48 |
| Month 24 (Year 2 end) | ×6.83 |
| Month 36 (Year 3 end) | ×5.17 |
| Month 48 (Year 4 end) | ×3.51 |
| Month 60 (Year 5 end) | ×1.86 |
| Month 66 | ×1.03 |
| Month 72 (Final snapshot) | ×0.20 |

---

## Mainnet Contracts

| Contract | Address |
|----------|---------|
| TrustcoinV6.2 | `0x454d106409890a9f336b5710d638d825a743a8a2` |
| EmissionBridge V6.1 | `0xa2e18bc91279922ad7536a487b47d74b4f108e3e` |
| TaxBridge V6.3 | `0x59ab99534d5b830b4db04f17f5bf546556dc6233` |

---
*Mathematics, not Promises.*