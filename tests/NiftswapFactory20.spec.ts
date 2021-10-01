import * as ethers from 'ethers'

import { AbstractContract, BigNumber, expect, RevertError } from './utils'

import * as utils from './utils'

import {
  ERC20TokenMock,
  ERC1155PackedBalanceMock,
  NiftyswapFactory20
} from 'src/gen/typechain'

import { web3 } from 'hardhat'

// init test wallets from package.json mnemonic

const { wallet: ownerWallet } = utils.createTestWallet(web3, 0)

const { wallet: userWallet, signer: userSigner } = utils.createTestWallet(web3, 2)

const { wallet: operatorWallet, signer: operatorSigner } = utils.createTestWallet(web3, 4)

describe('NiftyswapFactory20', () => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  let ownerAddress: string
  let userAddress: string
  let operatorAddress: string
  let erc20Abstract: AbstractContract
  let erc1155Abstract: AbstractContract
  let erc1155PackedAbstract: AbstractContract
  let niftyswapFactoryAbstract: AbstractContract
  let niftyswapExchangeAbstract: AbstractContract

  // ERC-1155 token
  let ownerERC1155Contract: ERC1155PackedBalanceMock
  let userERC1155Contract: ERC1155PackedBalanceMock
  let operatorERC1155Contract: ERC1155PackedBalanceMock

  // Base Tokens
  let ownerBaseTokenContract: ERC20TokenMock
  let userBaseTokenContract: ERC20TokenMock
  let operatorBaseTokenContract: ERC20TokenMock

  let niftyswapFactoryContract: NiftyswapFactory20

  // Token Param
  let types: number[] = []
  let values: number[] = []
  const nTokenTypes = 30 //560
  const nTokensPerType = 500000

  // load contract abi and deploy to test server
  beforeEach(async () => {
    ownerAddress = await ownerWallet.getAddress()
    userAddress = await userWallet.getAddress()
    operatorAddress = await operatorWallet.getAddress()
    erc20Abstract = await AbstractContract.fromArtifactName('ERC20TokenMock')
    erc1155Abstract = await AbstractContract.fromArtifactName('ERC1155Mock')
    erc1155PackedAbstract = await AbstractContract.fromArtifactName('ERC1155PackedBalanceMock')
    niftyswapFactoryAbstract = await AbstractContract.fromArtifactName('NiftyswapFactory20')
    niftyswapExchangeAbstract = await AbstractContract.fromArtifactName('NiftyswapExchange20')

    // Minting enough values for transfer for each types
    for (let i = 0; i < nTokenTypes; i++) {
      types.push(i)
      values.push(nTokensPerType)
    }
  })

  // deploy before each test, to reset state of contract
  beforeEach(async () => {
    // Deploy ERC-20
    ownerBaseTokenContract = (await erc20Abstract.deploy(ownerWallet)) as ERC20TokenMock
    userBaseTokenContract = (await ownerBaseTokenContract.connect(userSigner)) as ERC20TokenMock
    operatorBaseTokenContract = (await ownerBaseTokenContract.connect(operatorSigner)) as ERC20TokenMock

    // Deploy ERC-1155
    ownerERC1155Contract = (await erc1155PackedAbstract.deploy(ownerWallet)) as ERC1155PackedBalanceMock
    operatorERC1155Contract = (await ownerERC1155Contract.connect(operatorSigner)) as ERC1155PackedBalanceMock
    userERC1155Contract = (await ownerERC1155Contract.connect(userSigner)) as ERC1155PackedBalanceMock

    // Deploy Niftyswap factory
    niftyswapFactoryContract = (await niftyswapFactoryAbstract.deploy(ownerWallet, [ownerAddress])) as NiftyswapFactory20
  })

  describe('Getter functions', () => {
    describe('getExchange() function', () => {
      let exchangeAddress: string

      beforeEach(async () => {
        // Create exchange contract for the ERC-20/1155 token
        await niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
        )

        // Retrieve exchange address
        exchangeAddress = (
          await niftyswapFactoryContract.functions.tokensToExchange(
            ownerERC1155Contract.address,
            ownerBaseTokenContract.address,
          )
        )[0]
      })

      it('should return exchange address', async () => {
        const exchange_address = await niftyswapFactoryContract.functions.tokensToExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
        )
        await expect(exchange_address[0]).to.be.eql(exchangeAddress)
      })
    })
  })

  describe('createExchange() function', () => {
    beforeEach(async () => {})

    it('should REVERT if Token is 0x0', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(ZERO_ADDRESS, ownerBaseTokenContract.address, {
        gasLimit: 1000000
      })
      await expect(tx).to.be.rejectedWith(RevertError('NiftyswapExchange20#constructor:INVALID_INPUT'))
    })

    it('should REVERT if Base Token is 0x0', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(ownerERC1155Contract.address, ZERO_ADDRESS, {
        gasLimit: 1000000
      })
      await expect(tx).to.be.rejectedWith(RevertError('NiftyswapExchange20#constructor:INVALID_INPUT'))
    })

    it("should PASS if exchange doesn't exist yet", async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ownerERC1155Contract.address,
        ownerBaseTokenContract.address,
      )
      await expect(tx).to.be.fulfilled
    })

    it('should PASS if creating an exchange with a new base currency contract', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(ownerERC1155Contract.address, userAddress)
      await expect(tx).to.be.fulfilled
    })

    context('When successful transfer', () => {
      let tx: ethers.ContractTransaction
      let exchangeAddress: string

      beforeEach(async () => {
        tx = await niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
        )

        // Retrieve exchange address
        exchangeAddress = (
          await niftyswapFactoryContract.functions.tokensToExchange(
            ownerERC1155Contract.address,
            ownerBaseTokenContract.address,
          )
        )[0]
      })

      it('should REVERT if creating an existing exchange', async () => {
        const tx = niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
          {
            gasLimit: 1000000
          }
        )
        await expect(tx).to.be.rejectedWith(RevertError('NiftyswapFactory20#createExchange: EXCHANGE_ALREADY_CREATED'))
      })

      it('should emit NewExchange event', async () => {
        const receipt = await tx.wait(1)
        const ev = receipt.events!.pop()!
        expect(ev.event).to.be.eql('NewExchange')
      })

      describe('NewExchange Event', async () => {
        let args

        beforeEach(async () => {
          const receipt = await tx.wait(1)
          const ev = receipt.events!.pop()!
          args = ev.args! as any
        })

        it('should have token address as `token` field', async () => {
          expect(args.token).to.be.eql(ownerERC1155Contract.address)
        })

        it('should have Base Token address as `currency` field', async () => {
          expect(args.currency).to.be.eql(ownerBaseTokenContract.address)
        })

        it('should have the exchange contract address as `exchange` field', async () => {
          expect(args.exchange).to.be.eql(exchangeAddress)
        })
      })
    })
  })
})
