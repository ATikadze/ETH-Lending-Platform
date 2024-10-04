const { ethers } = require("hardhat");

module.exports = {
    toWei,
    getAccountWeiBalance
};

function toWei(num) {
    return BigInt(num * (10 ** 18));
}

async function getAccountWeiBalance(address) {
    return await ethers.provider.getBalance(address);
}