const SyCrowBarterFactory = artifacts.require("SyCrowBarterFactory");

const params = {
	avaxtest: {
    weth: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c",
		priceFeed: "0x5498BB86BC934c8D34FDA08E81D444153d0D06aD",
	},
	fantomtest: {
		weth: "0xf1277d1ed8ad466beddf92ef448a132661956621",
		priceFeed: "0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D",
	},
	matictest: {
    weth: "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889",
		priceFeed: "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada",
	},
	bsctest: {
    weth: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
		priceFeed: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
	},
  kovan: {
    weth: "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
    priceFeed: "0x9326BFA02ADD2366b30bacB125260Af641031331",
  },
  mainnet: {
    weth: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    priceFeed: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"
  },

	fantom: {
		weth: "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83",
		priceFeed: "0xf4766552D15AE4d256Ad41B6cf2933482B0680dc",
	},
	bsc: {
    weth: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
		priceFeed: "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE",
	},
	matic: {
    weth: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
		priceFeed: "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
	},
	avax: {
    weth: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
		priceFeed: "0x0A77230d17318075983913bC2145DB16C7366156",
	},
};

const BASE_FEE = 0x38D7EA4C68000;

module.exports = function (deployer, network) {
	deployer.deploy(SyCrowBarterFactory, BASE_FEE, params[network].priceFeed, params[network].weth);
};
