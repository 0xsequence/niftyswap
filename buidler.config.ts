import { usePlugin, BuidlerConfig } from '@nomiclabs/buidler/config'

usePlugin('@nomiclabs/buidler-truffle5')
usePlugin('buidler-gas-reporter')

const config: BuidlerConfig = {
  paths: {
    artifacts: './artifacts'
  },
  solc: {
    version: '0.6.8',
    optimizer: {
      enabled: true,
      runs: 200
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
