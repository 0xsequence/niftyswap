import { ethers, utils, BigNumber } from 'ethers'

export const UNIT_ETH = utils.parseEther('1')
export const HIGH_GAS_LIMIT = { gasLimit: 6_000_000 }
export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

import { BuyTokensObj, SellTokensObj, AddLiquidityObj, RemoveLiquidityObj, SellTokensObj20 } from 'src/typings/tx-types'
import {
  MethodSignature,
  MethodSignature20,
  BuyTokensType,
  SellTokensType,
  SellTokens20Type,
  AddLiquidityType,
  RemoveLiquidityType
} from '../../src/utils/constants'

// createTestWallet creates a new wallet
export const createTestWallet = (web3, addressIndex = 0) => {
  const provider = new Web3DebugProvider(web3.currentProvider)

  const { npm_package_config_mnemonic } = process.env
  if (!npm_package_config_mnemonic) {
    console.error('Missing npm_package_config_mnemonic')
    process.exit(1)
  }

  const wallet = ethers.Wallet.fromMnemonic(npm_package_config_mnemonic, `m/44'/60'/0'/0/${addressIndex}`).connect(provider)

  const signer = provider.getSigner(addressIndex)

  return { wallet, provider, signer }
}

// Check if tx was Reverted with specified message
export function RevertError(errorMessage?: string) {
  if (!errorMessage) {
    return /Transaction reverted and Hardhat couldn't infer the reason/
  } else {
    // return new RegExp(`${errorMessage}`)
    return new RegExp(`VM Exception while processing transaction: reverted with reason string ["']${errorMessage}["']`)
  }
}
export const CallError = () => /call revert exception/
export const OpCodeError = () => RegExp('^VM Exception while processing transaction: (revert|invalid opcode)$')
export const ArrayAccessError = () => /Array accessed at an out-of-bounds or negative index/
export const RevertUnsafeMathError = () => /Arithmetic operation .*flowed/

export interface JSONRPCRequest {
  jsonrpc: string
  id: number
  method: any
  params: any
}

export const getBuyTokenData = (
  recipient: string,
  types: number[] | BigNumber[],
  tokensAmountsToBuy: BigNumber[],
  deadline: number
) => {
  const buyTokenObj = {
    recipient: recipient,
    tokensBoughtIDs: types,
    tokensBoughtAmounts: tokensAmountsToBuy,
    deadline: deadline
  } as BuyTokensObj

  return ethers.utils.defaultAbiCoder.encode(['bytes4', BuyTokensType], [MethodSignature.BUYTOKENS, buyTokenObj])
}

export const getSellTokenData = (recipient: string, cost: BigNumber, deadline: number) => {
  const sellTokenObj = {
    recipient: recipient,
    minBaseTokens: cost,
    deadline: deadline
  } as SellTokensObj

  return ethers.utils.defaultAbiCoder.encode(['bytes4', SellTokensType], [MethodSignature.SELLTOKENS, sellTokenObj])
}

// Buy and sell data for ERC-20 exchange
export const getSellTokenData20 = (
  recipient: string,
  cost: BigNumber,
  deadline: number,
  extraFeeRecipients?: string[],
  extraFeeAmounts?: BigNumber[]
) => {
  const sellTokenObj = {
    recipient: recipient,
    minCurrency: cost,
    extraFeeRecipients: extraFeeRecipients ? extraFeeRecipients : [],
    extraFeeAmounts: extraFeeAmounts ? extraFeeAmounts : [],
    deadline: deadline
  } as SellTokensObj20

  return ethers.utils.defaultAbiCoder.encode(['bytes4', SellTokens20Type], [MethodSignature20.SELLTOKENS, sellTokenObj])
}

export const getAddLiquidityData = (maxCurrency: BigNumber[], deadline: number) => {
  const addLiquidityObj = { maxCurrency, deadline } as AddLiquidityObj

  return ethers.utils.defaultAbiCoder.encode(['bytes4', AddLiquidityType], [MethodSignature20.ADDLIQUIDITY, addLiquidityObj])
}

export const getRemoveLiquidityData = (minCurrency: BigNumber[], minTokens: BigNumber[], deadline: number) => {
  const removeLiquidityObj = { minCurrency, minTokens, deadline } as RemoveLiquidityObj

  return ethers.utils.defaultAbiCoder.encode(
    ['bytes4', RemoveLiquidityType],
    [MethodSignature20.REMOVELIQUIDITY, removeLiquidityObj]
  )
}

export class Web3DebugProvider extends ethers.providers.JsonRpcProvider {
  public reqCounter = 0
  public reqLog: JSONRPCRequest[] = []

  readonly _web3Provider: ethers.providers.ExternalProvider
  private _sendAsync: (request: any, callback: (error: any, response: any) => void) => void

  constructor(web3Provider: ethers.providers.ExternalProvider, network?: ethers.providers.Networkish) {
    // HTTP has a host; IPC has a path.
    super(web3Provider.host || web3Provider.path || '', network)

    if (web3Provider) {
      if (web3Provider.sendAsync) {
        this._sendAsync = web3Provider.sendAsync.bind(web3Provider)
      } else if (web3Provider.send) {
        this._sendAsync = web3Provider.send.bind(web3Provider)
      }
    }

    if (!web3Provider || !this._sendAsync) {
      console.error(ethers.errors.INVALID_ARGUMENT)
    }

    ethers.utils.defineReadOnly(this, '_web3Provider', web3Provider)
  }

  send(method: string, params: any): Promise<any> {
    this.reqCounter++

    return new Promise((resolve, reject) => {
      const request = {
        method: method,
        params: params,
        id: this.reqCounter,
        jsonrpc: '2.0'
      } as JSONRPCRequest
      this.reqLog.push(request)

      this._sendAsync(request, function (error, result) {
        if (error) {
          reject(error)
          return
        }

        if (result.error) {
          const error = new Error(result.error.message)
          error.code = result.error.code
          error.data = result.error.data
          reject(error)
          return
        }

        resolve(result.result)
      })
    })
  }

  getPastRequest(reverseIndex = 0): JSONRPCRequest {
    if (this.reqLog.length === 0) {
      return { jsonrpc: '2.0', id: 0, method: null, params: null }
    }
    return this.reqLog[this.reqLog.length - reverseIndex - 1]
  }
}
