const { ethers } = require("hardhat");

module.exports = {
    toWei,
    getAccountWeiBalance
};

const ethInWei = BigInt((10 ** 18));

function toWei(num) {
    return BigInt(num) * ethInWei;
}

async function getAccountWeiBalance(address) {
    return BigInt(await ethers.provider.getBalance(address));
}