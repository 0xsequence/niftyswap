import { Wallet } from 'ethers'
import { BigNumber } from 'ethers/utils'

export type GasReceipt = {
  gasLimit: number | string | BigNumber
  baseGas: number | string | BigNumber
  gasPrice: number | string | BigNumber
  feeRecipient: string
  feeTokenData: string | Uint8Array
}

export type TransferSignature = {
  contractAddress: string
  signerWallet: Wallet
  receiver: string
  id: number | string | BigNumber
  amount: number | string | BigNumber
  transferData: Uint8Array | null
  nonce: number | string | BigNumber
}

export type BatchTransferSignature = {
  contractAddress: string
  signerWallet: Wallet
  receiver: string
  ids: number[] | string[] | BigNumber[]
  amounts: number[] | string[] | BigNumber[]
  transferData: Uint8Array | null
  nonce: number | string | BigNumber
}

export type ApprovalSignature = {
  contractAddress: string
  signerWallet: Wallet
  operator: string
  approved: boolean
  nonce: number | string | BigNumber
}

export type BuyTokensObj = {
  recipient: string
  tokensBoughtIDs: number[] | string[] | BigNumber[]
  tokensBoughtAmounts: number[] | string[] | BigNumber[]
  deadline: number | string | BigNumber
}

export type SellTokensObj = {
  recipient: string
  minBaseTokens: number | string | BigNumber
  deadline: number | string | BigNumber
}

export type SellTokensObj20 = {
  recipient: string
  minCurrency: number | string | BigNumber
  extraFeeRecipients: string[]
  extraFeeAmounts: number[] | string[] | BigNumber[]
  deadline: number | string | BigNumber
}

export type AddLiquidityObj = {
  maxCurrency: number[] | string[] | BigNumber[]
  deadline: number | string | BigNumber
}

export type RemoveLiquidityObj = {
  minCurrency: number[] | string[] | BigNumber[]
  minTokens: number[] | string[] | BigNumber[]
  deadline: number | string | BigNumber
}
