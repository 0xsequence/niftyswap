import type { BlockTag } from '@ethersproject/providers'
import type { ethers } from 'ethers'

// Ethers typings are bad (https://github.com/ethers-io/ethers.js/issues/204#issuecomment-427059031)
export declare type EventFilter = ethers.EventFilter & {
  fromBlock?: BlockTag
  toBlock?: BlockTag
}
