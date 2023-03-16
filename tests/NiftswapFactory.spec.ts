import * as ethers from 'ethers'

import { AbstractContract, BigNumber, expect, HIGH_GAS_LIMIT, RevertError } from './utils'

import * as utils from './utils'

import { ERC1155Mock, ERC1155PackedBalanceMock, NiftyswapFactory } from 'src/gen/typechain'

import { web3 } from 'hardhat'

// init test wallets from package.json mnemonic

const { wallet: ownerWallet } = utils.createTestWallet(web3, 0)
const { wallet: userWallet } = utils.createTestWallet(web3, 2)

describe('NiftyswapFactory', () => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  let userAddress: string
  let erc1155Abstract: AbstractContract
  let erc1155PackedAbstract: AbstractContract
  let niftyswapFactoryAbstract: AbstractContract

  // Token
  let ownerERC1155Contract: ERC1155PackedBalanceMock
  let ownerBaseTokenContract: ERC1155Mock

  let niftyswapFactoryContract: NiftyswapFactory

  // Token Param
  const types: number[] = []
  const values: number[] = []
  const nTokenTypes = 30 //560
  const nTokensPerType = 500000

  // Base Token Param
  const baseTokenID = 666

  // load contract abi and deploy to test server
  beforeEach(async () => {
    userAddress = await userWallet.getAddress()
    erc1155Abstract = await AbstractContract.fromArtifactName('ERC1155Mock')
    erc1155PackedAbstract = await AbstractContract.fromArtifactName('ERC1155PackedBalanceMock')
    niftyswapFactoryAbstract = await AbstractContract.fromArtifactName('NiftyswapFactory')

    // Minting enough values for transfer for each types
    for (let i = 0; i < nTokenTypes; i++) {
      types.push(i)
      values.push(nTokensPerType)
    }
  })

  // deploy before each test, to reset state of contract
  beforeEach(async () => {
    // Deploy Base Token contract
    ownerBaseTokenContract = (await erc1155Abstract.deploy(ownerWallet)) as ERC1155Mock

    // Deploy ERC-1155
    ownerERC1155Contract = (await erc1155PackedAbstract.deploy(ownerWallet)) as ERC1155PackedBalanceMock

    // Deploy Niftyswap factory
    niftyswapFactoryContract = (await niftyswapFactoryAbstract.deploy(ownerWallet)) as NiftyswapFactory
  })

  describe('Getter functions', () => {
    describe('getExchange() function', () => {
      let exchangeAddress: string

      beforeEach(async () => {
        // Create exchange contract for the ERC-1155 token
        await niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
          baseTokenID
        )

        // Retrieve exchange address
        exchangeAddress = (
          await niftyswapFactoryContract.functions.tokensToExchange(
            ownerERC1155Contract.address,
            ownerBaseTokenContract.address,
            baseTokenID
          )
        )[0]
      })

      it('should return exchange address', async () => {
        const exchange_address = await niftyswapFactoryContract.functions.tokensToExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
          baseTokenID
        )
        await expect(exchange_address[0]).to.be.eql(exchangeAddress)
      })
    })
  })

  describe('createExchange() function', () => {
    it('should REVERT if Token is 0x0', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ZERO_ADDRESS,
        ownerBaseTokenContract.address,
        baseTokenID,
        HIGH_GAS_LIMIT
      )
      await expect(tx).to.be.rejectedWith(RevertError('NiftyswapExchange#constructor:INVALID_INPUT'))
    })

    it('should REVERT if Base Token is 0x0', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ownerERC1155Contract.address,
        ZERO_ADDRESS,
        baseTokenID,
        HIGH_GAS_LIMIT
      )
      await expect(tx).to.be.rejectedWith(RevertError('NiftyswapExchange#constructor:INVALID_INPUT'))
    })

    it("should PASS if exchange doesn't exist yet", async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ownerERC1155Contract.address,
        ownerBaseTokenContract.address,
        baseTokenID
      )
      await expect(tx).to.be.fulfilled
    })

    it('should PASS if creating an exchange with a new base ID', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ownerERC1155Contract.address,
        ownerBaseTokenContract.address,
        baseTokenID + 1
      )
      await expect(tx).to.be.fulfilled
    })

    it('should PASS if creating an exchange with a new base currency contract', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(ownerERC1155Contract.address, userAddress, baseTokenID)
      await expect(tx).to.be.fulfilled
    })

    it('should PASS if creating an exchange with both token contract being the same', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ownerERC1155Contract.address,
        ownerERC1155Contract.address,
        baseTokenID
      )
      await expect(tx).to.be.fulfilled
    })

    context('When successful transfer', () => {
      let tx: ethers.ContractTransaction
      let exchangeAddress: string

      beforeEach(async () => {
        tx = await niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
          baseTokenID
        )

        // Retrieve exchange address
        exchangeAddress = (
          await niftyswapFactoryContract.functions.tokensToExchange(
            ownerERC1155Contract.address,
            ownerBaseTokenContract.address,
            baseTokenID
          )
        )[0]
      })

      it('should REVERT if creating an existing exchange', async () => {
        const tx = niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address,
          ownerBaseTokenContract.address,
          baseTokenID,
          HIGH_GAS_LIMIT
        )
        await expect(tx).to.be.rejectedWith(RevertError('NiftyswapFactory#createExchange: EXCHANGE_ALREADY_CREATED'))
      })

      it('should emit NewExchange event', async () => {
        const receipt = await tx.wait(1)
        const ev = receipt.events?.pop()
        expect(ev?.event).to.be.eql('NewExchange')
      })

      describe('NewExchange Event', async () => {
        let args

        beforeEach(async () => {
          const receipt = await tx.wait(1)
          const ev = receipt.events?.pop()
          args = ev?.args as any
        })

        it('should have token address as `token` field', async () => {
          expect(args.token).to.be.eql(ownerERC1155Contract.address)
        })

        it('should have Base Token address as `currency` field', async () => {
          expect(args.currency).to.be.eql(ownerBaseTokenContract.address)
        })

        it('should have base token ID as `currencyID` field', async () => {
          expect(args.currencyID).to.be.eql(BigNumber.from(baseTokenID))
        })

        it('should have the exchange contract address as `exchange` field', async () => {
          expect(args.exchange).to.be.eql(exchangeAddress)
        })
      })
    })
  })
})
