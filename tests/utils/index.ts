import * as chai from 'chai'
import chaiAsPromised from 'chai-as-promised'
import ChaiBigNumber from 'chai-bignumber'
import chaiString from 'chai-string'
import * as ethers from 'ethers'

export * from './contract'
export * from './helpers'

const BigNumber = ethers.BigNumber
export { BigNumber }

export const { assert, expect } = chai.use(chaiString).use(chaiAsPromised).use(ChaiBigNumber()).use(ChaiBigNumber(BigNumber))
