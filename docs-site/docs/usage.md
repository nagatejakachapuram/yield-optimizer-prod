# Usage Guide

This guide explains how users interact with the AI-powered vaults.

---

## 1. Connect Wallet

* Use MetaMask or WalletConnect.
* Make sure you're on Sepolia testnet.

---

## 2. Choose Vault

* Go to the `AI Vault` tab.
* Select between:

  * **Low-Risk Vault:** allocates to Aave.
  * **High-Risk Vault:** allocates to Morpho/Curve.

---

## 3. Deposit USDC

* Input amount and confirm transaction.
* Vault receives your USDC and issues ERC4626 shares.

---

## 4. Wait for Allocation

* Funds are held until the AI agent picks a strategy.
* Chainlink Automation triggers `allocateFunds()`.
* Your deposit is deployed into the selected strategy.

---

## 5. View Your Balance

* You’ll see share value increase as strategies earn yield.
* Withdraw any time to redeem USDC.

---

## 6. Withdraw

* Navigate to Withdraw tab.
* Input amount or select “Max.”
* Vault burns shares and returns USDC.

---

## Notes

* You can deposit multiple times.
* Withdrawals only return assets available from current strategy.
* Only vault admins can pause deposits/withdrawals.

---

For strategy logic, see [ai-agent.md](ai-agent.md). For contract-level calls, see [api.md](api.md).