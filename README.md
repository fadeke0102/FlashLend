
 FlashLend

A decentralized microloan protocol built on Stacks blockchain that enables instant STX loans backed by collateral.

 Overview

FlashLend allows users to:
 Borrow: Get instant STX loans by providing 150% collateral
 Lend: Deposit STX to the liquidity pool and earn interest
 Liquidate: Claim collateral from expired loans

 Features

 Core Functionality
 Collateralized Lending: All loans require 150% collateralization in STX
 Instant Loans: Immediate loan disbursement upon collateral deposit
 Flexible Terms: Borrowers can set loan duration in blocks
 Automatic Liquidation: Expired loans can be liquidated by anyone
 Interest Payments: 10% interest rate on all loans

 Smart Contract Functions

 For Borrowers
 requestloan(amount, duration)  Request a new loan with collateral
 repayloan(loanid)  Repay loan and retrieve collateral
 getuserloans(user)  View all loans for a user

 For Lenders
 deposittopool(amount)  Add liquidity to earn interest
 withdrawfrompool(amount)  Remove liquidity from pool

 For Liquidators
 liquidateloan(loanid)  Liquidate expired loans

 ReadOnly Functions
 getloan(loanid)  Get loan details
 getpoolbalance()  View total pool liquidity
 calculaterequiredcollateral(amount)  Calculate collateral needed

 How It Works

1. Lenders deposit STX to the liquidity pool
2. Borrowers request loans by providing 150% collateral
3. Loans are automatically disbursed from the pool
4. Borrowers repay loans with 10% interest to retrieve collateral
5. Expired loans can be liquidated, with collateral going to the pool

 Security

 Comprehensive error handling with specific error codes
 Collateral ratio enforcement (150% minimum)
 Automatic expiry checking for liquidations
 Owneronly administrative functions
 Input validation for all monetary operations

 Getting Started

 Prerequisites
 Clarinet CLI installed
 Stacks wallet for testing

 Installation
bash
git clone 
cd flashlend
clarinet check
clarinet test


 Testing

shellscript
clarinet console


 Contract Details

 Collateral Ratio: 150% (configurable by owner)
 Interest Rate: 10% fixed
 Max Loans per User: 10
 Liquidation: Available after loan expiry


 Future Enhancements

 Variable interest rates based on utilization
 Governance token for protocol decisions
 Crosschain collateral support
 Automated market maker integration
 Insurance fund for bad debt protection


 License

MIT License
