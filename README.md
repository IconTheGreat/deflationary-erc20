# Deflationary ERC20 Token

This project implements a custom ERC20 token with a **deflationary mechanism** — a small percentage of tokens are burned on every transfer, reducing the total supply over time.

## Features
- ERC20 Standard: Fully compliant with the ERC20 interface.
- Deflationary Transfers: Automatically burns a set percentage of tokens from each transaction.
- Owner Controls: Token owner can adjust the burn rate.
- Supply Transparency: Public view functions for current total supply and burn rate.

## How It Works
When a transfer occurs:
1. The burn amount is calculated as `(amount * burnRate) / 100`.
2. The burn amount is sent to the zero address, reducing the total supply.
3. The remainder is sent to the recipient.

## Example
If burnRate is **2%** and Alice sends **100 tokens** to Bob:
- 2 tokens are burned.
- 98 tokens go to Bob.

## Requirements
- Solidity ^0.8.19

## Deployment
```bash

# Compile the contract
forge build

# Deploy using Foundry, Hardhat, or Remix
```

## License
MIT License
