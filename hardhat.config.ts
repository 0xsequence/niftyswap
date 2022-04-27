import { HardhatUserConfig } from 'hardhat/config'

import '@nomiclabs/hardhat-truffle5'
import "@nomiclabs/hardhat-ethers"
import 'hardhat-gas-reporter'
import '@tenderly/hardhat-tenderly'

const config: HardhatUserConfig = {
  solidity: {
    version: '0.7.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1650,
        details: {
          yul: true
        }
      }
    }
  },
  paths: {
    root: 'src',
    tests: '../tests'
  },
  networks: {
    ganache: {
      url: 'http://127.0.0.1:8545',
      blockGasLimit: 10000000
    },
    matic: {
      url: 'https://rpc-mainnet.matic.network'
    },
    hardhat: {
      blockGasLimit: 0xfffffffffff,
      gasPrice: 20000000000,
    }
  },
  gasReporter: {
    enabled: !!process.env.REPORT_GAS === true,
    currency: 'USD',
    gasPrice: 21,
    showTimeSpent: true
  }
}

export default config
