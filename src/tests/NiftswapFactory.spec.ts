import * as ethers from 'ethers'

import { 
  AbstractContract, 
  BigNumber, 
  expect,
  RevertError,
  getBuyTokenData,
  getSellTokenData,
  getAddLiquidityData,
  getRemoveLiquidityData,
} from './utils'

import * as utils from './utils'

import { ERC1155Mock } from 'typings/contracts/ERC1155Mock'
import { ERC1155PackedBalanceMock } from 'typings/contracts/ERC1155PackedBalanceMock'
import { NiftyswapExchange } from 'typings/contracts/NiftyswapExchange'
import { NiftyswapFactory } from 'typings/contracts/NiftyswapFactory'
//@ts-ignore
import { abi as exchangeABI } from './contracts/NiftyswapExchange.json'
import { Zero } from 'ethers/constants';

// init test wallets from package.json mnemonic
const web3 = (global as any).web3

const {
  wallet: ownerWallet,
  provider: ownerProvider,
  signer: ownerSigner
} = utils.createTestWallet(web3, 0)

const {
  wallet: userWallet,
  provider: userProvider,
  signer: userSigner
} = utils.createTestWallet(web3, 2)

const {
  wallet: operatorWallet,
  provider: operatorProvider,
  signer: operatorSigner
} = utils.createTestWallet(web3, 4)

const {
  wallet: randomWallet,
  provider: randomProvider,
  signer: randomSigner
} = utils.createTestWallet(web3, 5)

const getBig = (id: number) => new BigNumber(id);

contract('NiftyswapExchange', (accounts: string[]) => {
  const MAXVAL = new BigNumber(2).pow(256).sub(1) // 2**256 - 1
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  let ownerAddress: string
  let userAddress: string
  let operatorAddress: string
  let erc1155Abstract: AbstractContract
  let erc1155PackedAbstract: AbstractContract
  let niftyswapFactoryAbstract: AbstractContract
  let niftyswapExchangeAbstract: AbstractContract
  let operatorAbstract: AbstractContract

  // ERC-1155 token
  let ownerERC1155Contract: ERC1155PackedBalanceMock
  let userERC1155Contract: ERC1155PackedBalanceMock
  let operatorERC1155Contract: ERC1155PackedBalanceMock

  // Base Tokens
  let ownerBaseTokenContract: ERC1155Mock
  let userBaseTokenContract: ERC1155Mock
  let operatorBaseTokenContract: ERC1155Mock


  let niftyswapFactoryContract: NiftyswapFactory
  let niftyswapExchangeContract: NiftyswapExchange
  let operatorExchangeContract: NiftyswapExchange

  // Token Param
  let types: number[] = []
  let values: number[]  = []
  const nTokenTypes    = 30 //560
  const nTokensPerType = 500000

  // Base Token Param
  const baseTokenID = 666;
  const baseTokenAmount = new BigNumber(10000000).mul(new BigNumber(10).pow(18))

  // load contract abi and deploy to test server
  beforeEach(async () => {
    ownerAddress = await ownerWallet.getAddress()
    userAddress = await userWallet.getAddress()
    operatorAddress = await operatorWallet.getAddress()
    erc1155Abstract = await AbstractContract.fromArtifactName('ERC1155Mock')
    erc1155PackedAbstract = await AbstractContract.fromArtifactName('ERC1155PackedBalanceMock')
    niftyswapFactoryAbstract = await AbstractContract.fromArtifactName('NiftyswapFactory')
    niftyswapExchangeAbstract = await AbstractContract.fromArtifactName('NiftyswapExchange')

    // Minting enough values for transfer for each types
    for (let i = 0; i < nTokenTypes; i++) {
      types.push(i)
      values.push(nTokensPerType)
    }
  })

  // deploy before each test, to reset state of contract
  beforeEach(async () => {
    // Deploy Base Token contract
    ownerBaseTokenContract = await erc1155Abstract.deploy(ownerWallet) as ERC1155Mock
    userBaseTokenContract = await ownerBaseTokenContract.connect(userSigner) as ERC1155Mock
    operatorBaseTokenContract = await ownerBaseTokenContract.connect(operatorSigner) as ERC1155Mock


    // Deploy ERC-1155
    ownerERC1155Contract = await erc1155PackedAbstract.deploy(ownerWallet) as ERC1155PackedBalanceMock
    operatorERC1155Contract = await ownerERC1155Contract.connect(operatorSigner) as ERC1155PackedBalanceMock
    userERC1155Contract = await ownerERC1155Contract.connect(userSigner) as ERC1155PackedBalanceMock

    // Deploy Niftyswap factory
    niftyswapFactoryContract = await niftyswapFactoryAbstract.deploy(ownerWallet) as NiftyswapFactory
  })

  describe('Getter functions', () => {
    describe('getExchange() function', () => {
      let exchangeAddress: string;

      beforeEach(async () => {
        // Create exchange contract for the ERC-1155 token
        await niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address, 
          ownerBaseTokenContract.address, 
          baseTokenID
        )
        
        // Retrieve exchange address
        exchangeAddress = await niftyswapFactoryContract.functions.getExchange(ownerERC1155Contract.address)
      })

      it('should return exchange address', async () => {
        const exchange_address = await niftyswapFactoryContract.functions.getExchange(ownerERC1155Contract.address)
        await expect(exchange_address).to.be.eql(exchangeAddress)
      })
    })
  })

  describe('createExchange() function', () => {

    beforeEach(async () => {
    })

    it('should REVERT if Token is 0x0', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ZERO_ADDRESS, 
        ownerBaseTokenContract.address, 
        baseTokenID
      )
      await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#constructor:INVALID_INPUT"));
    })

    it('should REVERT if Base Token is 0x0', async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ownerERC1155Contract.address, 
        ZERO_ADDRESS, 
        baseTokenID
      )
      await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#constructor:INVALID_INPUT"));
    })

    it("should PASS if exchange doesn't exist yet", async () => {
      const tx = niftyswapFactoryContract.functions.createExchange(
        ownerERC1155Contract.address, 
        ownerBaseTokenContract.address, 
        baseTokenID
      )
      await expect(tx).to.be.fulfilled;
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
        exchangeAddress = await niftyswapFactoryContract.functions.getExchange(ownerERC1155Contract.address)
      })

      it("should REVERT if creating an existing exchange", async () => {
        const tx = niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address, 
          ownerBaseTokenContract.address, 
          baseTokenID
        )
        await expect(tx).to.be.rejectedWith(RevertError("NiftyswapFactory#createExchange: EXCHANGE_ALREADY_CREATED"));
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


        it('should have Base Token address as `baseToken` field', async () => {
          expect(args.baseToken).to.be.eql(ownerBaseTokenContract.address)
        })


        it('should have base token ID as `baseTokenID` field', async () => {
          expect(args.baseTokenID).to.be.eql(new BigNumber(baseTokenID))
        })


        it('should have the exchange contract address as `exchange` field', async () => {
          expect(args.exchange).to.be.eql(exchangeAddress)
        })

      })

    })

  })
})
