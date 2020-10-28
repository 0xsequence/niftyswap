import * as ethers from 'ethers'

export const UNIT_ETH = ethers.utils.parseEther('1')
export const HIGH_GAS_LIMIT = { gasLimit: 6e9 }
export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

import { 
  BuyTokensObj, 
  SellTokensObj, 
  AddLiquidityObj, 
  RemoveLiquidityObj 
} from '../../typings/txTypes'
import { BigNumber } from 'ethers';

// createTestWallet creates a new wallet
export const createTestWallet = (web3: any, addressIndex: number = 0) => {
  const provider = new Web3DebugProvider(web3.currentProvider)

  const wallet = ethers.Wallet
    .fromMnemonic(process.env.npm_package_config_mnemonic!, `m/44'/60'/0'/0/${addressIndex}`)
    .connect(provider)

  const signer = provider.getSigner(addressIndex)

  return { wallet, provider, signer }
}

// Check if tx was Reverted with specified message
export function RevertError(errorMessage?: string) {
  let prefix = 'VM Exception while processing transaction: revert'
  return errorMessage ? RegExp(`^${prefix + ' ' + errorMessage}$`) : RegExp(`^${prefix}$`)
}

export const methodsSignature = {
  BUYTOKENS: "0xb2d81047",
  SELLTOKENS: "0xdb08ec97",
  ADDLIQUIDITY: "0x82da2b73",
  REMOVELIQUIDITY: "0x5c0bf259"
}

export const BuyTokensType = `tuple(
  address recipient,
  uint256[] tokensBoughtIDs,
  uint256[] tokensBoughtAmounts,
  uint256 deadline
)`

export const SellTokensType = `tuple(
  address recipient,
  uint256 minBaseTokens,
  uint256 deadline
)`

export const AddLiquidityType = `tuple(
  uint256[] maxBaseTokens,
  uint256 deadline
)`

export const RemoveLiquidityType = `tuple(
  uint256[] minBaseTokens,
  uint256[] minTokens,
  uint256 deadline
)`

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
  deadline: number) => {
  const buyTokenObj = {
    recipient: recipient,
    tokensBoughtIDs: types,
    tokensBoughtAmounts: tokensAmountsToBuy,
    deadline: deadline
  } as BuyTokensObj


  return ethers.utils.defaultAbiCoder.encode(
    ['bytes4', BuyTokensType], [methodsSignature.BUYTOKENS, buyTokenObj])
}

export const getSellTokenData = (
  recipient: string,
  cost: BigNumber, 
  deadline: number
) => {
  const sellTokenObj = {
    recipient: recipient,
    minBaseTokens: cost,
    deadline: deadline
  } as SellTokensObj

  return ethers.utils.defaultAbiCoder.encode(
    ['bytes4', SellTokensType], [methodsSignature.SELLTOKENS, sellTokenObj])
}

export const getAddLiquidityData = (baseAmountsToAdd: BigNumber[], deadline: number) => {
  const addLiquidityObj = {
    maxBaseTokens: baseAmountsToAdd,
    deadline: deadline
  } as AddLiquidityObj

  return ethers.utils.defaultAbiCoder.encode(
    ['bytes4', AddLiquidityType], [methodsSignature.ADDLIQUIDITY, addLiquidityObj])
}

export const getRemoveLiquidityData = (minBaseTokens: BigNumber[], minTokens: BigNumber[], deadline: number) => {
  const removeLiquidityObj = {
    minBaseTokens: minBaseTokens,
    minTokens: minTokens,
    deadline: deadline
  } as RemoveLiquidityObj

  return ethers.utils.defaultAbiCoder.encode(
    ['bytes4', RemoveLiquidityType], [methodsSignature.REMOVELIQUIDITY, removeLiquidityObj])
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
      let request = {
        method: method,
        params: params,
        id: this.reqCounter,
        jsonrpc: '2.0'
      } as JSONRPCRequest
      this.reqLog.push(request)

      this._sendAsync(request, function(error, result) {
        if (error) {
          reject(error)
          return
        }

        if (result.error) {
          // @TODO: not any
          let error: any = new Error(result.error.message)
          error.code = result.error.code
          error.data = result.error.data
          reject(error)
          return
        }

        resolve(result.result)
      })
    })
  }

  getPastRequest(reverseIndex: number = 0): JSONRPCRequest {
    if (this.reqLog.length === 0) {
      return { jsonrpc: '2.0', id: 0, method: null, params: null }
    }
    return this.reqLog[this.reqLog.length-reverseIndex-1]
  }

}
