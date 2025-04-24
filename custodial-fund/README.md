# Offspring Trust Fund Smart Contract

## Overview

The Offspring Trust Fund is a Stacks blockchain smart contract designed for parents and guardians who want to establish trust funds for their children. The contract allows trustee accounts to lock STX tokens until a predetermined maturity date, ensuring financial resources are preserved for a child's future needs while providing necessary management flexibility.

## Features

- **Trust Account Creation**: Create dedicated trust funds for beneficiaries
- **Maturity-Based Access**: Funds are locked until a specified maturity date
- **Flexible Funding**: Add additional funds to existing trust accounts anytime
- **Multiple Managers**: Authorize up to 5 managers per trust account
- **Beneficiary Withdrawals**: Secure withdrawals when accounts reach maturity
- **Emergency Access**: Emergency withdrawal provisions for trustees
- **Account Management**: Update beneficiary details as needed

## Fee Structure

- **Registration Fee**: 5,000,000 microSTX (5 STX) per account creation
- **Minimum Deposit**: 5,000,000 microSTX (5 STX) initial deposit
- **Standard Withdrawal Fee**: 2% of withdrawal amount
- **Emergency Withdrawal Fee**: 10% of withdrawal amount (if withdrawn before maturity)

## Contract Functions

### Read Functions

- `get-contract-balance`: View total balance held by the contract
- `get-trust-account`: Retrieve information about a specific trust account
- `get-accumulated-fees`: Get total accumulated fees in the contract

### Write Functions

- `create-trust-account`: Establish a new trust fund for a beneficiary
- `deposit-to-trust`: Add additional funds to an existing trust account
- `beneficiary-withdrawal`: Allow beneficiary to withdraw funds from matured accounts
- `update-beneficiary-address`: Change the beneficiary's wallet address
- `trustee-emergency-withdrawal`: Emergency withdrawal function for trustees
- `withdraw-contract-fees`: Contract owner function to withdraw accumulated fees

### Trust Management Functions

- `add-trust-manager`: Add an authorized manager to a trust account
- `remove-trust-manager`: Remove a manager from a trust account

## Usage Examples

### Creating a Trust Account

```clarity
(contract-call? .offspring-trust-fund create-trust-account 
  "JohnDoe" 
  'SP123..456 
  u18 
  u10000000
)
```
This creates a trust account for "JohnDoe" with beneficiary address 'SP123..456', locked for 18 years, with an initial deposit of 10 STX.

### Adding Funds to a Trust

```clarity
(contract-call? .offspring-trust-fund deposit-to-trust
  'SP789..012
  "JohnDoe" 
  u5000000
)
```
This adds 5 STX to JohnDoe's trust account.

### Maturity Withdrawal

```clarity
(contract-call? .offspring-trust-fund beneficiary-withdrawal
  'SP789..012
  "JohnDoe"
)
```
Allows the beneficiary to withdraw funds after reaching maturity date (2% fee applies).

## Error Codes

- `ERR-ACCOUNT-ALREADY-EXISTS`: Trust account with this ID already exists
- `ERR-MINIMUM-DEPOSIT-REQUIRED`: Deposit amount is below minimum requirement
- `ERR-INSUFFICIENT-BALANCE`: Sender has insufficient balance
- `ERR-ACCOUNT-NOT-FOUND`: Specified trust account does not exist
- `ERR-UNAUTHORIZED-BENEFICIARY`: Sender is not the authorized beneficiary
- `ERR-ACCOUNT-NOT-MATURED`: Trust account has not reached maturity date
- `ERR-UNAUTHORIZED-MANAGER`: Sender is not authorized to manage this account
- `ERR-UNAUTHORIZED-TRUSTEE-OR-MANAGER`: Sender is not the trustee or authorized manager
- `ERR-UNAUTHORIZED-OWNER`: Sender is not the contract owner
- `ERR-NO-FEES-AVAILABLE`: No fees available for withdrawal
- `ERR-MANAGER-ALREADY-EXISTS`: Manager already exists in the list
- `ERR-MANAGER-LIST-FULL`: Manager list is at capacity (max 5)
- `ERR-MANAGER-NOT-FOUND`: Manager does not exist in the list

## Security Considerations

- Only authorized addresses can access trust funds
- Multi-manager support allows for backup access 
- Fee structure incentivizes keeping funds until maturity
- Contract owner cannot access trust funds, only accumulated fees

## Note for Developers

This smart contract uses Clarity, the programming language for the Stacks blockchain. Make sure to test thoroughly in a testnet environment before deploying to mainnet.