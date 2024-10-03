const { toWei } = require("../scripts/ethHelper");
const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Loans Contract Test", function () {
    let contractAsOwner;
    let contractAsBorrower;

    const now = Math.floor(Date.now() / 1000);

    const loanId = 1;
    const borrowAmount = toWei(15);
    const accumulatedInterest = borrowAmount / BigInt(100) * BigInt(5); // 5% of 15

    const lentAmount1 = toWei(10);
    const lentAmount2 = toWei(5);

    before(async function () {
        [ownerAccount, borrowerAccount, lenderAccount1, lenderAccount2] = await ethers.getSigners();

        const Contract = await ethers.getContractFactory("LoansTest", ownerAccount);
        contractAsOwner = await Contract.deploy();

        contractAsBorrower = contractAsOwner.connect(borrowerAccount);
    });

    it("Get Days Elapsed", async function () {
        const fiveDaysAgo = now - (5 * 24 * 60 * 60);

        expect(await contractAsOwner.getDaysElapsedTest(fiveDaysAgo))
            .to.equal(5);
    });

    it("Calculate Interest", async function () {
        expect(await contractAsOwner.calculateInterestTest(borrowAmount, now))
            .to.equal(accumulatedInterest);
    });

    it("Only Whitelist Test", async function () {
        await expect(contractAsBorrower.getLoanRepaymentDetails(0))
            .to.be.revertedWith("Unauthorized");

        await expect(contractAsBorrower.newLoan(borrowerAccount, 0, [], []))
            .to.be.revertedWith("Unauthorized");

        await expect(contractAsBorrower.loanPaid(0))
            .to.be.revertedWith("Unauthorized");
    });

    it("Only Owner Test", async function () {
        await expect(contractAsBorrower.addWhitelist(borrowerAccount))
            .to.be.reverted;

        await expect(contractAsBorrower.removeWhitelist(borrowerAccount))
            .to.be.reverted;

        await expect(contractAsOwner.addWhitelist(ownerAccount))
            .to.not.be.reverted;
    });

    it("New loan", async function () {

        await expect(contractAsOwner.newLoan(borrowerAccount, borrowAmount, [lenderAccount1, lenderAccount2], [lentAmount1]))
            .to.be.reverted;

        await expect(await contractAsOwner.newLoan(borrowerAccount, borrowAmount, [lenderAccount1, lenderAccount2], [lentAmount1, lentAmount2]))
            .to.emit(contractAsOwner, "LoanCreated")
            .withArgs(loanId, borrowerAccount, borrowAmount);
    });

    it("Get Borrower", async function () {
        expect(await contractAsBorrower.getBorrower(loanId))
            .to.be.equal(borrowerAccount);
    });

    it("Get Loan Repayment Details", async function () {
        const [amount, lenderAddresses, lentAmounts] = await contractAsOwner.getLoanRepaymentDetails(loanId)

        expect(amount).to.be.equal(borrowAmount);
        expect(lenderAddresses.length).to.be.equal(2);
        expect(lenderAddresses[0]).to.be.equal(lenderAccount1.address);
        expect(lenderAddresses[1]).to.be.equal(lenderAccount2.address);

        expect(lentAmounts.length).to.be.equal(2);
        expect(lentAmounts[0]).to.be.equal(lentAmount1);
        expect(lentAmounts[1]).to.be.equal(lentAmount2);
    });

    it("Calculate Debt", async function () {
        expect(await contractAsBorrower.calculateDebt(loanId))
            .to.be.equal(borrowAmount + accumulatedInterest);
    });

    it("Loan Paid", async function () {
        await expect(contractAsOwner.loanPaid(loanId))
            .to.not.be.reverted;

        await expect(contractAsOwner.loanPaid(loanId))
            .to.be.reverted;
    });
});