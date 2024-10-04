const { toWei, getAccountWeiBalance } = require("../scripts/ethHelper");
const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Full Contracts Test", function () {
    let erc20ContractAsOwner;
    let aggregatorV3ContractAsOwner;
    let loansContractAsOwner;
    let lendingPoolContractAsOwner;
    let borrowerContractAsOwner;
    let collateralsContractAsOwner;

    let lendingPoolContractAsLender1;
    let lendingPoolContractAsLender2;

    let erc20ContractAsBorrower;
    let borrowerContractAsBorrower;

    const weiComparisonTolerance = 10 ** 15; // Approximate gas fee

    const lender1DepositAmount = toWei(27);
    const lender2DepositAmount = toWei(13);
    const totalDepositAmount = lender1DepositAmount + lender2DepositAmount;

    const borrowAmount = toWei(16);
    const debtInterest = toWei(16) * BigInt(5) / BigInt(100);
    const borrowerDebt = borrowAmount + debtInterest;

    const usdtCollateral = 60_000;
    const usdtCollateralWithDecimals = usdtCollateral * (10 ** 6);
    const usdtTotalAmount = usdtCollateralWithDecimals * 1.7;

    let preLoanBorrowerBalance;
    let preLoanLender1Balance;
    let preLoanLender2Balance;

    const lender1Share = Number(lender1DepositAmount) / Number(totalDepositAmount);
    const lender2Share = Number(lender2DepositAmount) / Number(totalDepositAmount);

    const lender1LentAmount = lender1DepositAmount * borrowAmount / totalDepositAmount;
    const lender2LentAmount = lender2DepositAmount * borrowAmount / totalDepositAmount;

    const postLoanAvailableAmount1 = lender1DepositAmount - lender1LentAmount;
    const postLoanAvailableAmount2 = lender2DepositAmount - lender2LentAmount;

    const lender1InterestAmount = BigInt((Number(debtInterest) * (lender1Share * 1000)) / 1000);
    const lender2InterestAmount = BigInt((Number(debtInterest) * (lender2Share * 1000)) / 1000);

    const postRepayAvailableAmount1 = lender1DepositAmount + lender1InterestAmount;
    const postRepayAvailableAmount2 = lender2DepositAmount + lender2InterestAmount;

    const loanId = 1;

    before(async function () {
        [ownerAccount, lenderAccount1, lenderAccount2, borrowerAccount] = await ethers.getSigners();

        // ERC20 Contract
        const erc20ContractFactory = await ethers.getContractFactory("ERC20Test", ownerAccount);
        erc20ContractAsOwner = await erc20ContractFactory.deploy();

        erc20ContractAsBorrower = erc20ContractAsOwner.connect(borrowerAccount);

        // AggregatorV3 Contract
        const aggregatorV3ContractFactory = await ethers.getContractFactory("AggregatorV3Test", ownerAccount);
        aggregatorV3ContractAsOwner = await aggregatorV3ContractFactory.deploy();

        // Loans Contract
        const loansContractFactory = await ethers.getContractFactory("LoansTest", ownerAccount);
        loansContractAsOwner = await loansContractFactory.deploy();

        // Loans Contract
        const collateralsContractFactory = await ethers.getContractFactory("CollateralsTest", ownerAccount);
        collateralsContractAsOwner = await collateralsContractFactory.deploy(await aggregatorV3ContractAsOwner.getAddress());

        // Lending Pool Contract
        const lendingPoolContractFactory = await ethers.getContractFactory("LendingPoolTest", ownerAccount);
        lendingPoolContractAsOwner = await lendingPoolContractFactory.deploy(await loansContractAsOwner.getAddress());

        lendingPoolContractAsLender1 = lendingPoolContractAsOwner.connect(lenderAccount1);
        lendingPoolContractAsLender2 = lendingPoolContractAsOwner.connect(lenderAccount2);

        // Borrower Contract
        const borrowerContractFactory = await ethers.getContractFactory("BorrowerTest", ownerAccount);
        borrowerContractAsOwner = await borrowerContractFactory.deploy(await loansContractAsOwner.getAddress(), await lendingPoolContractAsOwner.getAddress(), await collateralsContractAsOwner.getAddress(), await erc20ContractAsOwner.getAddress());

        borrowerContractAsBorrower = borrowerContractAsOwner.connect(borrowerAccount);

        // Other
        await loansContractAsOwner.addWhitelist(await lendingPoolContractAsOwner.getAddress());
        await loansContractAsOwner.addWhitelist(await borrowerContractAsOwner.getAddress());

        await lendingPoolContractAsOwner.setBorrowerContract(await borrowerContractAsOwner.getAddress());

        await erc20ContractAsOwner.mint(borrowerAccount, usdtTotalAmount);

        await erc20ContractAsBorrower.approve(await borrowerContractAsOwner.getAddress(), usdtCollateralWithDecimals);

        preLoanBorrowerBalance = await getAccountWeiBalance(borrowerAccount);
        preLoanLender1Balance = await getAccountWeiBalance(lenderAccount1);
        preLoanLender2Balance = await getAccountWeiBalance(lenderAccount2);

        /* preLoanLender1Balance = await getAccountWeiBalance(lenderAccount1);
        preLoanLender2Balance = await getAccountWeiBalance(lenderAccount2); */

        /* console.log(await erc20ContractAsOwner.balanceOf(borrowerAccount));
        console.log(await erc20ContractAsOwner.allowance(borrowerAccount, await borrowerContractAsBorrower.getAddress())); */

        /*         console.log(await borrowerContractAsOwner.getContractAddress());
                console.log(await borrowerContractAsOwner.getAddress());
        
                console.log(await borrowerContractAsBorrower.getContractAddress());
                console.log(await borrowerContractAsBorrower.getAddress());
        
                console.log(ownerAccount.address);
                console.log(await borrowerContractAsOwner.msgSender());
        
                console.log(borrowerAccount.address);
                console.log(await borrowerContractAsBorrower.msgSender()); */
    });

    describe("Lender Deposits", async function () {
        it("Lender 1 Deposit", async function () {
            await lendingPoolContractAsLender1.depositETH({ value: lender1DepositAmount });

            expect(await lendingPoolContractAsLender1.getAvailableETHAmount())
                .to.be.equal(lender1DepositAmount);
        });

        it("Lender 2 Deposit", async function () {
            await lendingPoolContractAsLender2.depositETH({ value: lender2DepositAmount });

            expect(await lendingPoolContractAsLender2.getAvailableETHAmount())
                .to.be.equal(lender2DepositAmount);
        });

        it("Lending Pool Contract Balance", async function () {
            expect(await getAccountWeiBalance(lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount);
        });
    });

    describe("Collaterals", async function () {
        it("Validate LTV", async function () {
            /* console.log(await borrowerContractAsBorrower.ltv());
            console.log(await borrowerContractAsBorrower.calculateLTVTest(borrowAmount, usdtCollateral, await borrowerContractAsBorrower.getWeiPerUSDTTest())); */

            expect(await collateralsContractAsOwner.calculateLTVTest(borrowAmount, usdtCollateral, await collateralsContractAsOwner.getWeiPerUSDTTest()))
                .to.be.lessThan(await collateralsContractAsOwner.ltv());

            expect(await collateralsContractAsOwner.validateLTV(borrowAmount, usdtCollateral / 2))
                .to.be.equal(false);

            expect(await collateralsContractAsOwner.validateLTV(borrowAmount, usdtCollateral))
                .to.be.equal(true);
        });
    });

    describe("Borrow", async function () {
        it("Borrowing ETH", async function () {
            /*             console.log("Allowance: " + await erc20ContractAsOwner.allowance(borrowerAccount.address, borrowerContractAsBorrower.getAddress()));
                        console.log(borrowerAccount.address);
                        console.log(await borrowerContractAsBorrower.getAddress());
            
                        console.log("Allowance: " + await erc20ContractAsOwner.allowance(await borrowerContractAsBorrower.msgSender(), await borrowerContractAsBorrower.getContractAddress()));
                        console.log(await borrowerContractAsBorrower.msgSender());
                        console.log(await borrowerContractAsBorrower.getContractAddress()); */

            await expect(await borrowerContractAsBorrower.borrowETH(borrowAmount, usdtCollateral))
                .to.emit(loansContractAsOwner, "LoanCreated")
                .withArgs(loanId, borrowerAccount, borrowAmount);
        });

        it("Check USDT balance", async function () {
            expect(await erc20ContractAsBorrower.balanceOf(borrowerAccount))
                .to.be.equal(usdtTotalAmount - usdtCollateralWithDecimals);

            expect(await erc20ContractAsBorrower.balanceOf(await borrowerContractAsOwner.getAddress()))
                .to.be.equal(usdtCollateralWithDecimals);
        });

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(borrowerAccount) - preLoanBorrowerBalance)
                .to.be.closeTo(borrowAmount, weiComparisonTolerance);

            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount - borrowAmount);

            expect(await lendingPoolContractAsLender1.getAvailableETHAmount())
                .to.be.equal(postLoanAvailableAmount1);

            expect(await lendingPoolContractAsLender2.getAvailableETHAmount())
                .to.be.equal(postLoanAvailableAmount2);
        });
    });

    describe("Loans", async function () {
        it("Calculate Debt", async function () {
            expect(await loansContractAsOwner.calculateDebt(loanId))
                .to.be.equal(borrowerDebt);
        });
    });

    describe("Repayment", async function () {
        before("Repay", async function () {
            await borrowerContractAsBorrower.repayETHDebt(loanId, { value: borrowerDebt });
        });

        /* it("Check Loan Repayed", async function () {
            await expect(loansContractAsOwner.loanPaid(loanId))
                .to.be.reverted;
        }); */

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(borrowerAccount))
                .to.be.closeTo(preLoanBorrowerBalance - debtInterest, weiComparisonTolerance);

            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount + debtInterest);

            expect(await lendingPoolContractAsLender1.getAvailableETHAmount())
                .to.be.equal(postRepayAvailableAmount1);

            expect(await lendingPoolContractAsLender2.getAvailableETHAmount())
                .to.be.equal(postRepayAvailableAmount2);
        });

        it("Check USDT balance", async function () {
            // TODO: Implement in the future
        });
    });

    describe("Withdraw", async function () {
        before("Withdrawing ETH", async function () {
            await lendingPoolContractAsLender1.withdrawETH(postRepayAvailableAmount1);
            await lendingPoolContractAsLender2.withdrawETH(postRepayAvailableAmount2);
        });

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(0);

            expect(await lendingPoolContractAsLender1.getAvailableETHAmount())
                .to.be.equal(0);

            expect(await lendingPoolContractAsLender2.getAvailableETHAmount())
                .to.be.equal(0);

            expect(await getAccountWeiBalance(lenderAccount1.address))
                .to.be.closeTo(preLoanLender1Balance + lender1InterestAmount, weiComparisonTolerance);

            expect(await getAccountWeiBalance(lenderAccount2.address))
                .to.be.closeTo(preLoanLender2Balance + lender2InterestAmount, weiComparisonTolerance);
        });
    });
});