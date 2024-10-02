# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```


Terms:

1.	Lender: The person or entity who deposits money or provides the loan.
2.	Borrower: The person or entity who borrows the money.
3.	Lend: The action of providing funds or giving a loan to someone.
4.	Borrow: The action of taking a loan or funds from the lender.
5.	Loan: The amount of money or cryptocurrency given by the lender to the borrower.
6.	Repay: The action of the borrower returning the loan or settling the debt.


Description:

We need a decentralized platform where users can either lend their cryptocurrency to earn interest or borrow assets by providing collateral. The system should be self-sustaining and secure, involving interest calculations, collateral management, and liquidation mechanisms. Below are the detailed requirements:

DeFi Lending and Borrowing Protocol

General Description:

The platform will enable users to lock their crypto assets into a smart contract (as lenders) and receive interest based on the amount and time of their deposits. On the other hand, users can borrow assets by depositing other crypto as collateral. The system will ensure that the value of the borrowed asset is less than the value of the deposited collateral (overcollateralization) to secure the loan. If the value of the collateral drops below a critical level, the platform should trigger automatic liquidation.

Key Requirements:

1.	User Roles:
	•	Lenders: Users who deposit cryptocurrency into the lending pool. They will earn interest over time based on the assets they deposit.
	•	Borrowers: Users who lock their assets as collateral and borrow another cryptocurrency.
2.	Collateralized Borrowing:
	•	Borrowers must provide collateral that is worth more than the borrowed assets.
	•	The collateral-to-loan value ratio must be at least 150% (configurable). This ensures security in case the value of collateral falls.
3.	Interest Rates:
	•	Implement dynamic interest rates based on supply and demand in the pool.
	•	Lenders should earn interest based on how long their assets stay in the pool.
	•	Borrowers must pay interest on the borrowed assets.
4.	Liquidation Mechanism:
	•	If the value of the collateral drops below a certain threshold, the system should automatically trigger liquidation.
	•	Partial liquidation can be allowed, where only part of the collateral is sold to maintain the required ratio.
	•	Liquidators should be incentivized with a small bonus for performing the liquidation.
5.	Loan Health Monitoring:
	•	Implement a health factor system to monitor the safety of loans. If the health factor falls below 1, the loan becomes eligible for liquidation.
6.	Flash Loan Feature (Optional):
	•	Implement flash loans, allowing users to borrow without collateral as long as the loan is returned within the same transaction.
7.	Smart Contract Features:
	•	Supply and Withdraw: Users should be able to supply and withdraw assets freely.
	•	Borrow and Repay: Borrowers should be able to borrow and repay their loans at any time.
	•	Liquidation: Automate liquidation for undercollateralized loans.
8.	Security Features:
	•	Ensure reentrancy protection and safe arithmetic.
	•	Use external oracles for price feeds (e.g., Chainlink) to determine the value of assets and collateral.
9.	Governance (Optional):
	•	Add a governance token that allows users to vote on changes to interest rates, liquidation fees, and other platform parameters.
10.	Frontend Interface (Optional):
	•	A simple web interface where users can connect their wallets, view available pools, supply or borrow assets, and track their interest or loan status.

Additional Details:

	•	Supported Assets: Initially support popular assets like ETH, USDC, DAI, and LINK.
	•	Network: The protocol will be deployed on Ethereum or a layer-2 solution (like Polygon or Arbitrum) to reduce gas costs.
	•	Scalability: The smart contracts should be optimized for gas efficiency.