import { usePlugin, BuidlerConfig } from '@nomiclabs/buidler/config'

usePlugin('@nomiclabs/buidler-truffle5')
usePlugin("buidler-ethers-v5");
usePlugin('buidler-gas-reporter')

const config: BuidlerConfig = {
  paths: {
    artifacts: './artifacts'
  },
  solc: {
    version: '0.7.4',
    optimizer: {
      enabled: true,
      runs: 100000
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
