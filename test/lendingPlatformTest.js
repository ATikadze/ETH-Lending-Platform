const { toWei, getAccountWeiBalance } = require("../scripts/ethHelper");
const { ethers } = require("hardhat");
const { expect } = require("chai");

// TODO: Add third lender and check the repayed debt value shares
// TODO: Add liquidation tests
describe("Lending Platform Test", function () {
    let erc20ContractAsOwner;
    let erc20ContractAsBorrower;

    let aggregatorV3ContractAsOwner;

    let lendingPlatformAsOwner;
    let lendingPlatformAsLender1;
    let lendingPlatformAsLender2;
    let lendingPlatformAsBorrower;

    let loansContractAsOwner;
    let lendingPoolContractAsOwner;
    let collateralsContractAsOwner;

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

        // SafeMath
        const safeMathLibraryFactory = await ethers.getContractFactory("SafeMath", ownerAccount);
        const safeMathLibraryAsOwner = await safeMathLibraryFactory.deploy();

        // ERC20 Contract
        const erc20ContractFactory = await ethers.getContractFactory("ERC20Test", ownerAccount);
        erc20ContractAsOwner = await erc20ContractFactory.deploy();

        erc20ContractAsBorrower = erc20ContractAsOwner.connect(borrowerAccount);

        // AggregatorV3 Contract
        const aggregatorV3ContractFactory = await ethers.getContractFactory("AggregatorV3Test", ownerAccount);
        aggregatorV3ContractAsOwner = await aggregatorV3ContractFactory.deploy();

        // LendingPlatform Contract
        const lendingPlatformFactory = await ethers.getContractFactory("LendingPlatformTest", { libraries: { SafeMath: await safeMathLibraryAsOwner.getAddress() } }, ownerAccount);
        lendingPlatformAsOwner = await lendingPlatformFactory.deploy(await erc20ContractAsOwner.getAddress(), await erc20ContractAsOwner.getAddress(), await aggregatorV3ContractAsOwner.getAddress(), await erc20ContractAsOwner.getAddress()); // TODO: Add WETH and Uniswap Router addresses

        lendingPlatformAsLender1 = lendingPlatformAsOwner.connect(lenderAccount1);
        lendingPlatformAsLender2 = lendingPlatformAsOwner.connect(lenderAccount2);
        lendingPlatformAsBorrower = lendingPlatformAsOwner.connect(borrowerAccount);

        // Other Contracts
        loansContractAsOwner = new ethers.Contract(await lendingPlatformAsOwner.loans(), require("../artifacts/contracts/Tests/LoansTest.sol/LoansTest.json").abi, ownerAccount);
        lendingPoolContractAsOwner = new ethers.Contract(await lendingPlatformAsOwner.lendingPool(), require("../artifacts/contracts/Tests/LendingPoolTest.sol/LendingPoolTest.json").abi, ownerAccount);
        collateralsContractAsOwner = new ethers.Contract(await lendingPlatformAsOwner.collaterals(), require("../artifacts/contracts/Tests/CollateralsTest.sol/CollateralsTest.json").abi, ownerAccount);

        // Operations
        await erc20ContractAsOwner.mint(borrowerAccount, usdtTotalAmount);

        await erc20ContractAsBorrower.approve(await collateralsContractAsOwner.getAddress(), usdtCollateralWithDecimals);

        preLoanBorrowerBalance = await getAccountWeiBalance(borrowerAccount);
        preLoanLender1Balance = await getAccountWeiBalance(lenderAccount1);
        preLoanLender2Balance = await getAccountWeiBalance(lenderAccount2);
    });

    describe("Lender Deposits", async function () {
        it("Lender 1 Deposit", async function () {
            await lendingPlatformAsLender1.depositETH({ value: lender1DepositAmount });

            expect(await lendingPlatformAsLender1.getAvailableAmount())
                .to.be.equal(lender1DepositAmount);
        });

        it("Lender 2 Deposit", async function () {
            await lendingPlatformAsLender2.depositETH({ value: lender2DepositAmount });

            expect(await lendingPlatformAsLender2.getAvailableAmount())
                .to.be.equal(lender2DepositAmount);
        });

        it("Lending Pool Contract Balance", async function () {
            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount);
        });
    });

    describe("Collaterals", async function () {
        it("Validate LTV", async function () {
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
            await expect(await lendingPlatformAsBorrower.borrowETH(borrowAmount, usdtCollateral))
                .to.emit(loansContractAsOwner, "LoanCreated")
                .withArgs(loanId, borrowerAccount, borrowAmount);
        });

        it("Check USDT balance", async function () {
            expect(await erc20ContractAsBorrower.balanceOf(borrowerAccount))
                .to.be.equal(usdtTotalAmount - usdtCollateralWithDecimals);

            expect(await erc20ContractAsBorrower.balanceOf(await collateralsContractAsOwner.getAddress()))
                .to.be.equal(usdtCollateralWithDecimals);
        });

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(borrowerAccount) - preLoanBorrowerBalance)
                .to.be.closeTo(borrowAmount, weiComparisonTolerance);

            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount - borrowAmount);

            expect(await lendingPlatformAsLender1.getAvailableAmount())
                .to.be.equal(postLoanAvailableAmount1);

            expect(await lendingPlatformAsLender2.getAvailableAmount())
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
            await lendingPlatformAsBorrower.repayETHDebt(loanId, { value: borrowerDebt });
        });

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(borrowerAccount))
                .to.be.closeTo(preLoanBorrowerBalance - debtInterest, weiComparisonTolerance);

            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount + debtInterest);

            expect(await lendingPlatformAsLender1.getAvailableAmount())
                .to.be.equal(postRepayAvailableAmount1);

            expect(await lendingPlatformAsLender2.getAvailableAmount())
                .to.be.equal(postRepayAvailableAmount2);
        });

        it("Check USDT balance", async function () {
            await erc20ContractAsBorrower.transferFrom(await collateralsContractAsOwner.getAddress(), borrowerAccount, usdtCollateralWithDecimals);
            
            expect(await erc20ContractAsBorrower.balanceOf(borrowerAccount))
                .to.be.equal(usdtTotalAmount);

            expect(await erc20ContractAsBorrower.balanceOf(await collateralsContractAsOwner.getAddress()))
                .to.be.equal(0);
        });
    });

    describe("Withdraw", async function () {
        before("Withdrawing ETH", async function () {
            await lendingPlatformAsLender1.withdrawETH(postRepayAvailableAmount1);
            await lendingPlatformAsLender2.withdrawETH(postRepayAvailableAmount2);
        });

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(0);

            expect(await lendingPlatformAsLender1.getAvailableAmount())
                .to.be.equal(0);

            expect(await lendingPlatformAsLender2.getAvailableAmount())
                .to.be.equal(0);

            expect(await getAccountWeiBalance(lenderAccount1.address))
                .to.be.closeTo(preLoanLender1Balance + lender1InterestAmount, weiComparisonTolerance);

            expect(await getAccountWeiBalance(lenderAccount2.address))
                .to.be.closeTo(preLoanLender2Balance + lender2InterestAmount, weiComparisonTolerance);
        });
    });
});