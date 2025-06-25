# Architecture

This protocol consists of off-chain and on-chain components, connected through Chainlink Automation and a permissioned controller contract (`AutomationOwner`).

## Diagram Overview
```mermaid
flowchart TD
    U["User"]
    A["Frontend UI<br/>(Assets / AI Vault Tabs)"]
    B["LowRiskVault<br/>(USDC Vault)"]
    C["HighRiskVault<br/>(USDC Vault)"]
    D["LowRiskAaveStrategy"]
    E["HighRiskMorphoStrategy"]
    F["MockAavePool"]
    G["MockMorphoPool"]
    H["AutomationOwner"]
    I["Chainlink Automation<br/>(allocateFunds)"]
    J["AI Agent<br/>(7d/25d Trend Analyzer)"]
    K["ElizaOS KV<br/>(Market Signal Store)"]
    L["CoinGecko & DefiLlama<br/>(Market Data)"]

    %% Connections
    U --> A
    A --> B
    A --> C
    B --> D
    C --> E
    D --> F
    E --> G
    H --> B
    H --> C
    I --> H
    J --> I
    J --> K
    J --> L

---



## Key Contracts

### YVault

* ERC4626-compliant vault for USDC.
* Accepts deposits, issues shares, manages strategy allocation.

### Strategy Contracts

* Each strategy implements `IStrategy` interface with `execute(address user, uint256 amount)`.
* LowRiskAaveStrategy: lends to Aave stable markets.
* HighRiskMorphoStrategy: allocates to Morpho Blue / Curve-like vaults.

### AutomationOwner

* Owns and manages vault `setStrategy()` calls.
* Only address authorized for Chainlink Automation.

### VaultFactory

* Deploys vaults per risk level (e.g. "low", "high").
* Sets initial strategy and AutomationOwner.

## Off-Chain Components

### AI Agent (ElizaOS)

* Gathers DeFi data from Aave, Curve, CoinGecko, etc.
* Classifies market trend and selects pool per strategy type.
* Stores decision in ElizaOS KV.

### Chainlink Automation

* Calls `AutomationOwner.updateVaultStrategy(vault, strategy)`
* Executes based on scheduled or AI-prompted triggers.

## Benefits of `AutomationOwner`

* Clean separation of on-chain authority.
* Safer than giving Chainlink access directly to vault.
* Enables centralized override or fallback if needed.

---

See [ai-agent.md](ai-agent.md) for more on how the AI works, or [api.md](api.md) for smart contract functions.
