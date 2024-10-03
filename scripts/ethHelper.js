module.exports = {
    toWei,
};

function toWei(num) {
    return BigInt(num * (10 ** 18));
}