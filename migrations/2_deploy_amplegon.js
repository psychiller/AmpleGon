const Amplegon = artifacts.require("Amplegon");

const MarketOracle = artifacts.require("MarketOracle");

const MonetaryPolicy = artifacts.require("MonetaryPolicy");

const UniswapFactory = artifacts.require("IUniswapV2Factory");

module.exports = function (deployer) {
    
    await deployer.deploy(Amplegon);
    await deployer.deploy(MonetaryPolicy);
    await deployer.deploy(MarketOracle, 900, ""); // chainlink price feed for eth or matic price

    const amplegon = await Amplegon.deployed();
    const monetaryPolicy = await MonetaryPolicy.deployed();
    const oracle = await MarketOracle.deployed();
    await amplegon.initialize(""); // owner address

    const uniswapFactory = await UniswapFactory.at(""); // factory address

    const pairAddress = await uniswapFactory.createPair(amplegon.address, ""); // weth or wmatic address
    
    await monetaryPolicy.initialize("", pairAddress, oracle.address, amplegon.address);

    await amplegon.setMonetaryPolicy(monetaryPolicy.address);

};
