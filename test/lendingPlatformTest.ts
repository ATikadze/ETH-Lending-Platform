const { toWei, getAccountWeiBalance } = require("../scripts/ethHelper.ts");
const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Lending Platform Test", function () {
    let erc20ContractAsOwner;
    let erc20ContractAsBorrower;

    let wethContractAsOwner;

    let aggregatorV3ContractAsOwner;

    let uniswapRouterContractAsOwner;

    let lendingPlatformAsOwner;
    let lendingPlatformAsLender1;
    let lendingPlatformAsLender2;
    let lendingPlatformAsBorrower;
    let lendingPlatformAsLiquidator;

    let loansContractAsOwner;
    let lendingPoolContractAsOwner;
    let collateralsContractAsOwner;

    const weiComparisonTolerance = 10 ** 15; // Approximate gas fee

    const lender1DepositAmount = toWei(27);
    const lender2DepositAmount = toWei(13);
    const totalDepositAmount = lender1DepositAmount + lender2DepositAmount;

    const borrowAmount = toWei(16);
    const debtInterest = borrowAmount * BigInt(5) / BigInt(100);
    const borrowerDebt = borrowAmount + debtInterest;

    const usdtDecimalsCount = 6;
    const usdtDecimals = (10 ** usdtDecimalsCount);

    const usdtCollateral = 60_000;
    const usdtCollateralWithDecimals = usdtCollateral * usdtDecimals;
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

    const loanId = 1;

    const usdtPerEther1 = 2500;
    const usdtPerEther2 = 3500;

    const weiPerUSDT1 = BigInt(10 ** 8) / BigInt(usdtPerEther1) * BigInt(10 ** 10)
    const weiPerUSDT2 = BigInt(10 ** 8) / BigInt(usdtPerEther2) * BigInt(10 ** 10);

    const uniswapWETHMintAmount = (BigInt(usdtCollateral) * BigInt(10 ** 18)) / BigInt(usdtPerEther2);
    const wethETHBalance = uniswapWETHMintAmount * BigInt(2);

    const liquidationAmount = ((borrowAmount * BigInt(10) / weiPerUSDT2) - BigInt(8 * usdtCollateral)) / BigInt(2);
    const liquidationAmountWithDecimals = liquidationAmount * BigInt(usdtDecimals);
    const liquidationCoveredDebt = liquidationAmount * weiPerUSDT2;

    const postLiquidationBorrowAmount = borrowAmount - liquidationCoveredDebt;

    const postLiquidationUSDTCollateral = BigInt(usdtCollateral) - liquidationAmount;
    const postLiquidationUSDTCollateralWithDecimals = postLiquidationUSDTCollateral * BigInt(usdtDecimals);

    const postLiquidationDebtInterest = postLiquidationBorrowAmount * BigInt(5) / BigInt(100);
    const postLiquidationBorrowerDebt = postLiquidationBorrowAmount + postLiquidationDebtInterest;

    const lender1InterestAmount = BigInt((Number(postLiquidationDebtInterest) * (lender1Share * 1000)) / 1000);
    const lender2InterestAmount = BigInt((Number(postLiquidationDebtInterest) * (lender2Share * 1000)) / 1000);

    const postRepayAvailableAmount1 = lender1DepositAmount + lender1InterestAmount;
    const postRepayAvailableAmount2 = lender2DepositAmount + lender2InterestAmount;

    before(async function () {
        [ownerAccount, lenderAccount1, lenderAccount2, borrowerAccount, liquidatorAccount] = await ethers.getSigners();

        // MathHelper
        const mathHelperLibraryFactory = await ethers.getContractFactory("MathHelper", ownerAccount);
        const mathHelperLibraryAsOwner = await mathHelperLibraryFactory.deploy();

        // ERC20 Contract
        const erc20ContractFactory = await ethers.getContractFactory("ERC20Test", ownerAccount);
        erc20ContractAsOwner = await erc20ContractFactory.deploy("Mock USDT", "MUSDT");

        erc20ContractAsBorrower = erc20ContractAsOwner.connect(borrowerAccount);

        // WETH Contract
        const wethContractFactory = await ethers.getContractFactory("WETHTest", ownerAccount);
        wethContractAsOwner = await wethContractFactory.deploy();

        // AggregatorV3 Contract
        const aggregatorV3ContractFactory = await ethers.getContractFactory("AggregatorV3Test", ownerAccount);
        aggregatorV3ContractAsOwner = await aggregatorV3ContractFactory.deploy();

        // Uniswap Router Contract
        const uniswapRouterContractFactory = await ethers.getContractFactory("UniswapV2RouterTest", ownerAccount);
        uniswapRouterContractAsOwner = await uniswapRouterContractFactory.deploy();

        // LendingPlatform Contract
        const lendingPlatformFactory = await ethers.getContractFactory("LendingPlatformTest", { libraries: { MathHelper: await mathHelperLibraryAsOwner.getAddress() } }, ownerAccount);
        lendingPlatformAsOwner = await lendingPlatformFactory.deploy(usdtDecimalsCount, await erc20ContractAsOwner.getAddress(), await wethContractAsOwner.getAddress(), await aggregatorV3ContractAsOwner.getAddress(), await uniswapRouterContractAsOwner.getAddress());

        lendingPlatformAsLender1 = lendingPlatformAsOwner.connect(lenderAccount1);
        lendingPlatformAsLender2 = lendingPlatformAsOwner.connect(lenderAccount2);
        lendingPlatformAsBorrower = lendingPlatformAsOwner.connect(borrowerAccount);
        lendingPlatformAsLiquidator = lendingPlatformAsOwner.connect(liquidatorAccount);

        // Other Contracts
        loansContractAsOwner = new ethers.Contract(await lendingPlatformAsOwner.loans(), require("../artifacts/contracts/Tests/LoansTest.sol/LoansTest.json").abi, ownerAccount);
        lendingPoolContractAsOwner = new ethers.Contract(await lendingPlatformAsOwner.lendingPool(), require("../artifacts/contracts/Tests/LendingPoolTest.sol/LendingPoolTest.json").abi, ownerAccount);
        collateralsContractAsOwner = new ethers.Contract(await lendingPlatformAsOwner.collaterals(), require("../artifacts/contracts/Tests/CollateralsTest.sol/CollateralsTest.json").abi, ownerAccount);

        // ...
        await erc20ContractAsOwner.mint(borrowerAccount, usdtTotalAmount);

        await erc20ContractAsBorrower.approve(await collateralsContractAsOwner.getAddress(), usdtCollateralWithDecimals);

        preLoanBorrowerBalance = await getAccountWeiBalance(borrowerAccount);
        preLoanLender1Balance = await getAccountWeiBalance(lenderAccount1);
        preLoanLender2Balance = await getAccountWeiBalance(lenderAccount2);

        await aggregatorV3ContractAsOwner.setUSDTPricePerEther(usdtPerEther1);

        await wethContractAsOwner.mint(await uniswapRouterContractAsOwner.getAddress(), uniswapWETHMintAmount);
        await wethContractAsOwner.deposit({ value: wethETHBalance });

        // Logs
        /* console.log("USDT Contract: " + await erc20ContractAsOwner.getAddress());
        console.log("WETH Contract: " + await wethContractAsOwner.getAddress());
        console.log("Aggregator V3 Contract Contract: " + await aggregatorV3ContractAsOwner.getAddress());
        console.log("Uniswap Router Contract: " + await uniswapRouterContractAsOwner.getAddress());
        console.log("Lending Platform Contract: " + await lendingPlatformAsOwner.getAddress());
        console.log("Loans Contract: " + await lendingPlatformAsOwner.lendingPool());
        console.log("Lending Pool Contract: " + await lendingPlatformAsOwner.loans());
        console.log("Collaterals Contract: " + await lendingPlatformAsOwner.collaterals()); */
    });

    describe("Lender Deposits", async function () {
        it("Lender 1 Deposit", async function () {
            await lendingPlatformAsLender1.depositETH({ value: lender1DepositAmount });

            expect(await lendingPlatformAsLender1.getAvailableAmount())
                .to.be.equal(lender1DepositAmount);
        });

        it("Lender 2 Deposit", async function () {
            await lenderAccount2.sendTransaction({
                to: await lendingPlatformAsLender2.getAddress(),
                value: lender2DepositAmount
            });

            expect(await lendingPlatformAsLender2.getAvailableAmount())
                .to.be.equal(lender2DepositAmount);
        });

        it("Lending Pool Contract Balance", async function () {
            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount);
        });
    });

    describe("Collaterals", async function () {
        it("Check LTV", async function () {
            expect(await collateralsContractAsOwner.calculateLTVTest(borrowAmount, usdtCollateral, await collateralsContractAsOwner.getWeiPerUSDTTest()))
                .to.be.lessThanOrEqual(await collateralsContractAsOwner.ltv());

            expect(await collateralsContractAsOwner.validateLTV(borrowAmount, usdtCollateral / 2))
                .to.be.equal(false);

            expect(await collateralsContractAsOwner.validateLTV(borrowAmount, usdtCollateral))
                .to.be.equal(true);

            expect(await collateralsContractAsOwner.calculateLiquidationTest(borrowAmount, usdtCollateral, await collateralsContractAsOwner.getWeiPerUSDTTest()))
                .to.be.equal(0);
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

    describe("Liquidation", async function () {
        it("Increase ETH Price + Liquidation/LTV Checks", async function () {
            await aggregatorV3ContractAsOwner.setUSDTPricePerEther(usdtPerEther2);

            expect(await collateralsContractAsOwner.calculateLTVTest(borrowAmount, usdtCollateral, await collateralsContractAsOwner.getWeiPerUSDTTest()))
                .to.be.greaterThan(await collateralsContractAsOwner.ltv());

            expect(await collateralsContractAsOwner.calculateLiquidationTest(borrowAmount, usdtCollateral, await collateralsContractAsOwner.getWeiPerUSDTTest()))
                .to.be.equal(liquidationAmount);
        });

        it("Liquidate", async function () {
            await expect(await lendingPlatformAsLiquidator.liquidateCollateral(loanId))
                .to.emit(collateralsContractAsOwner, "CollateralLiquidated")
                .withArgs(liquidationAmount, liquidationCoveredDebt);
        });

        it("Check Debt/Collateral", async function () {
            const [borrower, amount, collateralAmount, borrowedTimestamp, paidTimestamp, totalDebt] = await loansContractAsOwner.getLoanDetails(loanId);

            expect(amount).to.be.equal(postLiquidationBorrowAmount);

            expect(collateralAmount).to.be.equal(postLiquidationUSDTCollateral);

            expect(totalDebt).to.be.equal(postLiquidationBorrowerDebt);
        });

        it("Check LTV", async function () {
            expect(await collateralsContractAsOwner.calculateLTVTest(postLiquidationBorrowAmount, postLiquidationUSDTCollateral, await collateralsContractAsOwner.getWeiPerUSDTTest()))
                .to.be.lessThanOrEqual(await collateralsContractAsOwner.ltv());
        });

        it("Check USDT balance", async function () {
            expect(await erc20ContractAsBorrower.balanceOf(await collateralsContractAsOwner.getAddress()))
                .to.be.equal(postLiquidationUSDTCollateralWithDecimals);
        });

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount - borrowAmount + liquidationCoveredDebt);

            expect(await lendingPlatformAsLender1.getAvailableAmount())
                .to.be.equal(postLoanAvailableAmount1 + BigInt((liquidationCoveredDebt * BigInt((lender1Share * 1000))) / BigInt(1000)));

            expect(await lendingPlatformAsLender2.getAvailableAmount())
                .to.be.equal(postLoanAvailableAmount2 + BigInt((liquidationCoveredDebt * BigInt((lender2Share * 1000))) / BigInt(1000)));
        });
    });

    describe("Repayment", async function () {
        before("Repay", async function () {
            await lendingPlatformAsBorrower.repayETHDebt(loanId, { value: postLiquidationBorrowerDebt });
        });

        it("Check ETH balance", async function () {
            expect(await getAccountWeiBalance(borrowerAccount))
                .to.be.closeTo(preLoanBorrowerBalance + liquidationCoveredDebt - postLiquidationDebtInterest, weiComparisonTolerance);

            expect(await getAccountWeiBalance(await lendingPoolContractAsOwner.getAddress()))
                .to.be.equal(totalDepositAmount + postLiquidationDebtInterest);

            expect(await lendingPlatformAsLender1.getAvailableAmount())
                .to.be.equal(postRepayAvailableAmount1);

            expect(await lendingPlatformAsLender2.getAvailableAmount())
                .to.be.equal(postRepayAvailableAmount2);
        });

        it("Check USDT balance", async function () {
            expect(await erc20ContractAsBorrower.balanceOf(borrowerAccount))
                .to.be.equal(BigInt(usdtTotalAmount) - liquidationAmountWithDecimals);

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