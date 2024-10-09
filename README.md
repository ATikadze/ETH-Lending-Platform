# ETH - USDT Lending Platform

#### About:

This platform allows users to borrow ETH by providing USDT as collateral. It’s composed of four key contracts: **LendingPlatform**, **Collaterals**, **LendingPool**, and **Loans**, each handling a specific part of the system.

- **LendingPlatform** serves as the main entry point, coordinating interactions between the loans, lending pool, and collateral contracts. Borrowers can deposit USDT as collateral and take out ETH loans, while lenders provide ETH liquidity to the platform.
  
- **Collaterals** manages collateral-related operations, including deposits, withdrawals, and liquidation. It monitors the Loan-to-Value (LTV) ratio, ensuring that the value of the collateral remains sufficient. If the LTV ratio exceeds a safe threshold, the collateral is liquidated to cover the debt. This contract also integrates Chainlink price feeds to fetch the USDT/ETH price and Uniswap for swapping assets during liquidation.

- **LendingPool** is responsible for managing ETH deposits from lenders and distributing ETH to borrowers. It tracks the available liquidity and allocates loans based on available capital. Lenders can deposit and withdraw ETH, while the contract handles repayments from borrowers.

- **Loans** tracks individual loans, including their amounts, collateral, and repayment status. It calculates interest on loans and manages repayments, as well as handling loan changes through the liquidation process.

The platform ensures secure and decentralized lending by enforcing strict collateral management and integrating well-known services like Chainlink for price data and Uniswap for liquidity management.


#### Terms:

1.	Lender: The person or entity who deposits money or provides the loan.
2.	Borrower: The person or entity who borrows the money.
3.	Lend: The action of providing funds or giving a loan to someone.
4.	Borrow: The action of taking a loan or funds from the lender.
5.	Loan: The amount of money or cryptocurrency given by the lender to the borrower.
6.	Repay: The action of the borrower returning the loan or settling the debt.


#### Architecture:
![Architecture Diagram](https://github.com/ATikadze/ETH-Lending-Platform/blob/b4c27f8004d4fd78b34f14e1c6fecf3b184597e9/assets/Architecture.png)


#### Testing:
For testing, try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
```
