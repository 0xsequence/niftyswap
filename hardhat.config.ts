import { HardhatUserConfig } from 'hardhat/config'

import '@nomiclabs/hardhat-truffle5'
import "@nomiclabs/hardhat-ethers"
import 'hardhat-gas-reporter'

const config: HardhatUserConfig = {
  paths: {
    artifacts: './artifacts'
  },
  solidity: {
    version: '0.7.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000
      }
    }
  },
  networks: {
    ganache: {
      url: 'http://127.0.0.1:8545',
      blockGasLimit: 10000000
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
