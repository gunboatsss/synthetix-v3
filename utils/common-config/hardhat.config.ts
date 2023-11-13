/* eslint-disable @typescript-eslint/ban-ts-comment */

import path from 'node:path';
import dotenv from 'dotenv';

import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-contract-sizer';
import 'solidity-coverage';
import 'hardhat-gas-reporter';
import 'hardhat-cannon';
import 'hardhat-ignore-warnings';
import '@synthetixio/hardhat-storage';

// Load common .env file from root
dotenv.config({ path: path.resolve(__dirname, '..', '..', '.env') });

const lockedConfig = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: false,
      runs: 200,
    },
  },
};

const config = {
  solidity: {
    compilers: [
      {
        version: '0.8.22',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
    overrides: {
      'contracts/Proxy.sol': lockedConfig,
      'contracts/modules/CoreModule.sol': lockedConfig,
    },
  },
  defaultNetwork: 'cannon',
  networks: {
    local: {
      url: 'http://localhost:8545',
      chainId: 31337,
      gas: 12000000, // Prevent gas estimation for better error results in tests
    },
    hardhat: {
      gas: 12000000, // Prevent gas estimation for better error results in tests
    },
    mainnet: {
      url:
        process.env.NETWORK_ENDPOINT ||
        'https://mainnet.infura.io/v3/' + process.env.INFURA_API_KEY,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      chainId: 1,
    },
    ['optimistic-goerli']: {
      url:
        process.env.NETWORK_ENDPOINT ||
        `https://optimism-goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      chainId: 420,
    },
    ['optimistic-mainnet']: {
      url:
        process.env.NETWORK_ENDPOINT ||
        `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      chainId: 10,
    },
    goerli: {
      url:
        process.env.NETWORK_ENDPOINT || `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      chainId: 5,
    },
    ['avalanche-fuji']: {
      url:
        process.env.NETWORK_ENDPOINT ||
        `https://avalanche-fuji.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      chainId: 43113,
    },
    sepolia: {
      url:
        process.env.NETWORK_ENDPOINT ||
        `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      chainId: 11155111,
    },
  },
  gasReporter: {
    enabled: !!process.env.REPORT_GAS,
  },
  contractSizer: {
    strict: true,
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      rinkeby: process.env.ETHERSCAN_API_KEY,
      goerli: process.env.ETHERSCAN_API_KEY,
      optimisticEthereum: process.env.OVM_ETHERSCAN_API_KEY,
      optimisticGoerli: process.env.OVM_ETHERSCAN_API_KEY,
      avalancheFujiTestnet: process.env.ETHERSCAN_API_KEY,
    },
  },
  tenderly: {
    project: 'synthetix',
    username: 'synthetix-services',
  },
  cannon: {
    publicSourceCode: true,
  },
  typechain: {
    target: 'ethers-v5',
  },
};

export default config;
