const HDWalletProvider = require("@truffle/hdwallet-provider");

require('dotenv').config(); 

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*"
    },
    avaxtest: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://api.avax-test.network/ext/bc/C/rpc"),
      network_id: 43113,
      gas: 8000000,
      gasPrice: 225000000000,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    fantom: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://rpcapi.fantom.network"),
      network_id: 250,
      gasPrice: 22000000000,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    fantomtest: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://rpc.testnet.fantom.network"),
      network_id: 4002,
      gasPrice: 22000000000,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    mainnet: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY),
      port: 8545,
      network_id: 1,
      gas: 10000000,
      gasPrice: 4000000000
    },

    kovan: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://ropsten.infura.io/v3/" + process.env.INFURA_API_KEY),
      port: 8545,
      network_id: 3,
      gas: 10000000,
      gasPrice: 40000000000
    },
    bsctest: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://data-seed-prebsc-1-s1.binance.org:8545"),
      network_id: 97,
      gas: 3527407,
      gasPrice: 10000000000000000000,
      networkCheckTimeoutnetworkCheckTimeout: 10000,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://bsc-dataseed.binance.org/"),
      network_id: 56,
      gasPrice: 22000000000,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    matictest: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://rpc-mumbai.matic.today"),
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 200,
      networkCheckTimeoutnetworkCheckTimeout: 10000,
      skipDryRun: true
    },
    matic: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, "https://polygon-rpc.com/"),
      network_id: 56,
      gasPrice: 22000000000,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8545,        
      gas: 0xfffffffffff, 
      gasPrice: 0x01     
    },
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
  contracts_build_directory: "./build",
  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.13",      // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
       settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 9999999
        },
      //  evmVersion: "byzantium"
      // }
    }
  },

  // Truffle DB is currently disabled by default; to enable it, change enabled:
  // false to enabled: true. The default storage location can also be
  // overridden by specifying the adapter settings, as shown in the commented code below.
  //
  // NOTE: It is not possible to migrate your contracts to truffle DB and you should
  // make a backup of your artifacts to a safe location before enabling this feature.
  //
  // After you backed up your artifacts you can utilize db by running migrate as follows:
  // $ truffle migrate --reset --compile-all
  //
  // db: {
    // enabled: false,
    // host: "127.0.0.1",
    // adapter: {
    //   name: "sqlite",
    //   settings: {
    //     directory: ".db"
    //   }
    // }
  // }
  }
}
