/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils
} from 'ethers'
import type { FunctionFragment, Result } from '@ethersproject/abi'
import type { Listener, Provider } from '@ethersproject/providers'
import type { TypedEventFilter, TypedEvent, TypedListener, OnEvent, PromiseOrValue } from '../common'

export interface IWrapAndNiftyswapInterface extends utils.Interface {
  functions: {
    'onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)': FunctionFragment
    'onERC1155Received(address,address,uint256,uint256,bytes)': FunctionFragment
    'wrapAndSwap(uint256,address,bytes)': FunctionFragment
  }

  getFunction(nameOrSignatureOrTopic: 'onERC1155BatchReceived' | 'onERC1155Received' | 'wrapAndSwap'): FunctionFragment

  encodeFunctionData(
    functionFragment: 'onERC1155BatchReceived',
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>[],
      PromiseOrValue<BigNumberish>[],
      PromiseOrValue<BytesLike>
    ]
  ): string
  encodeFunctionData(
    functionFragment: 'onERC1155Received',
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BytesLike>
    ]
  ): string
  encodeFunctionData(
    functionFragment: 'wrapAndSwap',
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<string>, PromiseOrValue<BytesLike>]
  ): string

  decodeFunctionResult(functionFragment: 'onERC1155BatchReceived', data: BytesLike): Result
  decodeFunctionResult(functionFragment: 'onERC1155Received', data: BytesLike): Result
  decodeFunctionResult(functionFragment: 'wrapAndSwap', data: BytesLike): Result

  events: {}
}

export interface IWrapAndNiftyswap extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this
  attach(addressOrName: string): this
  deployed(): Promise<this>

  interface: IWrapAndNiftyswapInterface

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>

  listeners<TEvent extends TypedEvent>(eventFilter?: TypedEventFilter<TEvent>): Array<TypedListener<TEvent>>
  listeners(eventName?: string): Array<Listener>
  removeAllListeners<TEvent extends TypedEvent>(eventFilter: TypedEventFilter<TEvent>): this
  removeAllListeners(eventName?: string): this
  off: OnEvent<this>
  on: OnEvent<this>
  once: OnEvent<this>
  removeListener: OnEvent<this>

  functions: {
    onERC1155BatchReceived(
      arg0: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _ids: PromiseOrValue<BigNumberish>[],
      _amounts: PromiseOrValue<BigNumberish>[],
      _data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>

    onERC1155Received(
      _operator: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _id: PromiseOrValue<BigNumberish>,
      _amount: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>

    wrapAndSwap(
      _maxAmount: PromiseOrValue<BigNumberish>,
      _recipient: PromiseOrValue<string>,
      _niftyswapOrder: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>
  }

  onERC1155BatchReceived(
    arg0: PromiseOrValue<string>,
    _from: PromiseOrValue<string>,
    _ids: PromiseOrValue<BigNumberish>[],
    _amounts: PromiseOrValue<BigNumberish>[],
    _data: PromiseOrValue<BytesLike>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>

  onERC1155Received(
    _operator: PromiseOrValue<string>,
    _from: PromiseOrValue<string>,
    _id: PromiseOrValue<BigNumberish>,
    _amount: PromiseOrValue<BigNumberish>,
    _data: PromiseOrValue<BytesLike>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>

  wrapAndSwap(
    _maxAmount: PromiseOrValue<BigNumberish>,
    _recipient: PromiseOrValue<string>,
    _niftyswapOrder: PromiseOrValue<BytesLike>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>

  callStatic: {
    onERC1155BatchReceived(
      arg0: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _ids: PromiseOrValue<BigNumberish>[],
      _amounts: PromiseOrValue<BigNumberish>[],
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<string>

    onERC1155Received(
      _operator: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _id: PromiseOrValue<BigNumberish>,
      _amount: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<string>

    wrapAndSwap(
      _maxAmount: PromiseOrValue<BigNumberish>,
      _recipient: PromiseOrValue<string>,
      _niftyswapOrder: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<void>
  }

  filters: {}

  estimateGas: {
    onERC1155BatchReceived(
      arg0: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _ids: PromiseOrValue<BigNumberish>[],
      _amounts: PromiseOrValue<BigNumberish>[],
      _data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>

    onERC1155Received(
      _operator: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _id: PromiseOrValue<BigNumberish>,
      _amount: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>

    wrapAndSwap(
      _maxAmount: PromiseOrValue<BigNumberish>,
      _recipient: PromiseOrValue<string>,
      _niftyswapOrder: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>
  }

  populateTransaction: {
    onERC1155BatchReceived(
      arg0: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _ids: PromiseOrValue<BigNumberish>[],
      _amounts: PromiseOrValue<BigNumberish>[],
      _data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>

    onERC1155Received(
      _operator: PromiseOrValue<string>,
      _from: PromiseOrValue<string>,
      _id: PromiseOrValue<BigNumberish>,
      _amount: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>

    wrapAndSwap(
      _maxAmount: PromiseOrValue<BigNumberish>,
      _recipient: PromiseOrValue<string>,
      _niftyswapOrder: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>
  }
}