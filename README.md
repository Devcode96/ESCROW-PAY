# ESCROW-PAY

A secure escrow system enabling trustless payments and service agreements on the Stacks blockchain.

## Overview

ESCROW-PAY facilitates secure transactions between buyers and sellers with optional third-party arbitration, ensuring both parties fulfill their obligations before funds are released.

## Features

- **Secure Escrow**: Funds held in contract until conditions are met
- **Multi-party Approval**: Buyer and seller must both approve release
- **Arbitration System**: Optional third-party dispute resolution
- **Timeout Protection**: Automatic refund after specified period
- **Communication**: Built-in messaging between parties
- **Platform Fees**: Configurable fee structure for sustainability

## Contract Functions

### Public Functions

- `create-escrow(seller, arbiter, amount, description, timeout-blocks)` - Create new escrow
- `approve-release(escrow-id)` - Approve fund release (buyer/seller)
- `release-funds(escrow-id)` - Release funds after dual approval
- `request-refund(escrow-id)` - Request refund after timeout
- `arbiter-resolve(escrow-id, release-to-seller)` - Arbiter dispute resolution
- `add-message(escrow-id, message)` - Add communication message
- `set-platform-fee(new-fee)` - Admin function to update fees

### Read-Only Functions

- `get-escrow(escrow-id)` - Get complete escrow details
- `get-escrow-message(escrow-id, sender)` - Get message from specific sender
- `get-platform-fee()` - Get current platform fee percentage

## Usage

### Creating an Escrow
1. Call `create-escrow` with seller, optional arbiter, amount, and timeout
2. STX is automatically transferred to escrow contract
3. Escrow becomes active and awaits completion

### Completing a Transaction
1. Both buyer and seller call `approve-release`
2. Either party can then call `release-funds`
3. Funds transfer to seller minus platform fee

### Dispute Resolution
1. If arbiter is specified, they can call `arbiter-resolve`
2. Arbiter decides whether to release funds to seller or refund buyer
3. Decision is final and immediately executed

### Refund Process
1. If timeout period expires without completion
2. Buyer can call `request-refund` to recover funds
3. Automatic refund without seller approval

## Security Features

- **Timeout Protection**: Prevents indefinite fund locking
- **Dual Approval**: Both parties must agree to release
- **Arbiter Override**: Neutral third-party can resolve disputes
- **Message System**: Transparent communication trail
- **Fee Caps**: Maximum platform fee limits

## Use Cases

- **Service Payments**: Pay for services upon completion
- **Product Sales**: Secure online marketplace transactions
- **Freelance Work**: Milestone-based project payments
- **Digital Assets**: Safe transfer of valuable digital items
- **Business Agreements**: Secure B2B transaction processing