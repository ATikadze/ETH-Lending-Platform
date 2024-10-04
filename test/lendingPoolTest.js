const { toWei, getAccountWeiBalance } = require("../scripts/ethHelper");
const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Lending Pool Contract Test", function () {
    let contractAsOwner;
    let contractAsLender1;
    let contractAsLender2;

    let preLendBorrowerBalance;

    const depositAmount1 = toWei(7);
    const depositAmount2 = toWei(3);
    const totalAvailableAmount = depositAmount1 + depositAmount2;
    const borrowAmount = toWei(6);

    const postLendAvailableAmount1 = depositAmount1 - (depositAmount1 * borrowAmount / totalAvailableAmount);
    const postLendAvailableAmount2 = depositAmount2 - (depositAmount2 * borrowAmount / totalAvailableAmount);

    before(async function () {
        [ownerAccount, lenderAccount1, lenderAccount2, borrowerAccount] = await ethers.getSigners();

        const loansContractFactory = await ethers.getContractFactory("LoansTest", ownerAccount);
        const loansContract = await loansContractFactory.deploy();

        const lendingPoolContractFactory = await ethers.getContractFactory("LendingPoolTest", ownerAccount);
        contractAsOwner = await lendingPoolContractFactory.deploy(loansContract.getAddress());

        await loansContract.addWhitelist(contractAsOwner.getAddress());

        contractAsLender1 = contractAsOwner.connect(lenderAccount1);
        contractAsLender2 = contractAsOwner.connect(lenderAccount2);

        await contractAsOwner.setBorrowerContract(ownerAccount);

        preLendBorrowerBalance = await getAccountWeiBalance(borrowerAccount);
    });

    it("Deposit ETH 1", async function () {
        const preDepositBalance = await getAccountWeiBalance(lenderAccount1);

        await expect(contractAsLender1.depositETH())
            .to.be.reverted;

        await expect(contractAsLender1.depositETH({ value: depositAmount1 }))
            .to.be.not.reverted;

        expect(await contractAsLender1.getAvailableETHAmount())
            .to.be.equal(depositAmount1);

        expect(preDepositBalance - await getAccountWeiBalance(lenderAccount1))
            .to.be.greaterThan(depositAmount1);
    });

    it("Deposit ETH 2", async function () {
        const preDepositBalance = await getAccountWeiBalance(lenderAccount2);

        await expect(contractAsLender2.depositETH({ value: depositAmount2 }))
            .to.be.not.reverted;

        expect(await contractAsLender2.getAvailableETHAmount())
            .to.be.equal(depositAmount2);

        expect(preDepositBalance - await getAccountWeiBalance(lenderAccount2))
            .to.be.greaterThan(depositAmount2);
    });

    it("Check Contract Balance 1", async function () {
        expect(await getAccountWeiBalance(contractAsOwner.getAddress()))
            .to.be.equal(totalAvailableAmount);
    });

    it("Lend ETH", async function () {
        await expect(contractAsOwner.lendETH(borrowerAccount, borrowAmount))
            .to.not.be.reverted;
    });

    it("Check Contract Balance 2", async function () {
        expect(await getAccountWeiBalance(contractAsOwner.getAddress()))
            .to.be.equal(totalAvailableAmount - borrowAmount);
    });

    it("Check Lender 1 Available Amount 1", async function () {
        expect(await contractAsLender1.getAvailableETHAmount())
            .to.be.equal(postLendAvailableAmount1);
    });

    it("Check Lender 2 Available Amount 1", async function () {
        expect(await contractAsLender2.getAvailableETHAmount())
            .to.be.equal(postLendAvailableAmount2);
    });

    it("Check Borrower Balance", async function () {
        expect(await getAccountWeiBalance(borrowerAccount) - preLendBorrowerBalance)
            .to.be.equal(borrowAmount);
    });

    it("Withdraw ETH 1", async function () {
        await expect(contractAsLender1.withdrawETH(postLendAvailableAmount1 + BigInt(1)))
            .to.be.reverted;

        await expect(contractAsLender1.withdrawETH(postLendAvailableAmount1))
            .to.not.be.reverted;
    });

    it("Withdraw ETH 2", async function () {
        await expect(contractAsLender2.withdrawETH(postLendAvailableAmount2))
            .to.not.be.reverted;
    });

    it("Check Lender 1 Available Amount 2", async function () {
        expect(await contractAsLender1.getAvailableETHAmount())
            .to.be.equal(0);
    });

    it("Check Lender 2 Available Amount 2", async function () {
        expect(await contractAsLender2.getAvailableETHAmount())
            .to.be.equal(0);
    });

    it("Check Contract Balance 3", async function () {
        expect(await getAccountWeiBalance(contractAsOwner.getAddress()))
            .to.be.equal(0);
    });

    // TODO: Possibly come back to this
    /* it("Repay ETH", async function () {
        await expect(contractAsOwner.repayETH(0, { value: borrowAmount }))
            .to.not.be.reverted;
    }); */
});