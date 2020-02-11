import * as ethers from 'ethers'

import { 
  AbstractContract, 
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
import { BigNumber } from 'ethers/utils';

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
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  let ownerAddress: string
  let userAddress: string
  let operatorAddress: string
  let erc1155Abstract: AbstractContract
  let erc1155PackedAbstract: AbstractContract
  let niftyswapFactoryAbstract: AbstractContract

  // ERC-1155 token
  let ownerERC1155Contract
  let userERC1155Contract
  let operatorERC1155Contract

  // Base Tokens
  let ownerBaseTokenContract: ERC1155Mock
  let userBaseTokenContract: ERC1155Mock
  let operatorBaseTokenContract: ERC1155Mock

  let niftyswapFactoryContract: NiftyswapFactory
  let niftyswapExchangeContract: NiftyswapExchange
  let operatorExchangeContract: NiftyswapExchange

  // Token Param
  const nTokenTypes    = 30 //560
  const nTokensPerType = 500000

  // Base Token Param
  const baseTokenID = 666;
  const baseTokenAmount = new BigNumber(10000000).mul(new BigNumber(10).pow(18))

  // Add liquidity data
  const tokenAmountToAdd = new BigNumber(300);
  const baseAmountToAdd = (new BigNumber(10).pow(18)).mul(300)

  // Transactions parameters
  const TX_PARAM = {gasLimit: 5000000}
  
  // Arrays
  const types = new Array(nTokenTypes).fill('').map((a, i) => getBig(i))
  const values = new Array(nTokenTypes).fill('').map((a, i) => nTokensPerType)
  const baseAmountsToAdd: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => baseAmountToAdd)
  const tokenAmountsToAdd: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToAdd)
  const addLiquidityData: string = getAddLiquidityData(baseAmountsToAdd, 10000000)

  // load contract abi and deploy to test server
  before(async () => {
    ownerAddress = await ownerWallet.getAddress()
    userAddress = await userWallet.getAddress()
    operatorAddress = await operatorWallet.getAddress()
    erc1155Abstract = await AbstractContract.fromArtifactName('ERC1155Mock')
    erc1155PackedAbstract = await AbstractContract.fromArtifactName('ERC1155PackedBalanceMock')
    niftyswapFactoryAbstract = await AbstractContract.fromArtifactName('NiftyswapFactory')
  })

  let conditions = [
    ["Seperate Token Contracts", 1], 
    ["Seperate Token Contracts (Packed)", 2],
    ["Same Token Contract", 3]
  ]

  let erc1155_error_prefix;

  conditions.forEach(function(condition) {
    context(condition[0] as string, () => {

      // deploy before each test, to reset state of contract
      beforeEach(async () => {
        // Deploy ERC-1155
        if (condition[1] == 1 || condition[1] == 3) {
          ownerERC1155Contract = await erc1155Abstract.deploy(ownerWallet) as ERC1155Mock
          operatorERC1155Contract = await ownerERC1155Contract.connect(operatorSigner) as ERC1155Mock
          userERC1155Contract = await ownerERC1155Contract.connect(userSigner) as ERC1155Mock
          erc1155_error_prefix = "ERC1155#"

        } else if (condition[1] == 2) {
          ownerERC1155Contract = await erc1155PackedAbstract.deploy(ownerWallet) as ERC1155PackedBalanceMock
          operatorERC1155Contract = await ownerERC1155Contract.connect(operatorSigner) as ERC1155PackedBalanceMock
          userERC1155Contract = await ownerERC1155Contract.connect(userSigner) as ERC1155PackedBalanceMock
          erc1155_error_prefix = "ERC1155PackedBalance#"
        }

        // Deploy Base Token contract
        if (condition[1] == 1 || condition[1] == 2) {
          ownerBaseTokenContract = await erc1155Abstract.deploy(ownerWallet) as ERC1155Mock
        } else if (condition[1] == 3) {
          ownerBaseTokenContract = await ownerERC1155Contract.connect(ownerSigner) as ERC1155Mock
        }
        userBaseTokenContract = await ownerBaseTokenContract.connect(userSigner) as ERC1155Mock
        operatorBaseTokenContract = await ownerBaseTokenContract.connect(operatorSigner) as ERC1155Mock

        // Deploy Niftyswap factory
        niftyswapFactoryContract = await niftyswapFactoryAbstract.deploy(ownerWallet) as NiftyswapFactory

        // Create exchange contract for the ERC-1155 token
        await niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address, 
          ownerBaseTokenContract.address, 
          baseTokenID
        )
        
        // Retrieve exchange address
        const exchangeAddress = await niftyswapFactoryContract.functions.tokensToExchange(ownerERC1155Contract.address, ownerBaseTokenContract.address, baseTokenID)
        
        // Type exchange contract
        niftyswapExchangeContract = new ethers.Contract(exchangeAddress, exchangeABI, ownerProvider) as NiftyswapExchange
        operatorExchangeContract = niftyswapExchangeContract.connect(operatorSigner) as NiftyswapExchange

        // Mint Token to owner and user
        await ownerERC1155Contract.functions.batchMintMock(operatorAddress, types, values, [])
        await ownerERC1155Contract.functions.batchMintMock(userAddress, types, values, [])

        // Mint Base token to owner and user
        await ownerBaseTokenContract.functions.mintMock(operatorAddress, baseTokenID, baseTokenAmount, [])
        await ownerBaseTokenContract.functions.mintMock(userAddress, baseTokenID, baseTokenAmount, [])

        // Authorize Niftyswap to transfer funds on your behalf for addLiquidity & transfers
        await operatorBaseTokenContract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
        await operatorERC1155Contract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
        await userBaseTokenContract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
        await userERC1155Contract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
      })

      describe('Getter functions', () => {
        describe('getTokenAddress() function', () => {
          it('should return token address', async () => {
            const token_address = await niftyswapExchangeContract.functions.getTokenAddress()
            await expect(token_address).to.be.eql(ownerERC1155Contract.address)
          })
        })

        describe('getBaseTokenInfo() function', () => {
          it('should return base token address and ID', async () => {
            const token_info = await niftyswapExchangeContract.functions.getBaseTokenInfo()
            await expect(token_info[0]).to.be.eql(ownerBaseTokenContract.address)
            await expect(token_info[1]).to.be.eql(new BigNumber(baseTokenID))
          })
        })

        describe('getFactoryAddress() function', () => {
          it('should return factory address', async () => {
            const factory_address = await niftyswapExchangeContract.functions.getFactoryAddress()
            await expect(factory_address).to.be.eql(niftyswapFactoryContract.address)
          })
        })

        describe('supportsInterface()', () => {
          it('should return true for 0x01ffc9a7 (ERC165)', async () => {
            const support = await niftyswapExchangeContract.functions.supportsInterface('0x01ffc9a7')
            expect(support).to.be.eql(true)
          })

          it('should return true for 0x4e2312e0 (ERC1155Receiver)', async () => {
            const support = await niftyswapExchangeContract.functions.supportsInterface('0x4e2312e0')
            expect(support).to.be.eql(true)
          })
        })
      })

      describe('_addLiquidity() function', () => {
        it('should pass when balances are sufficient', async () => {
          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 50000000}
          )
          await expect(tx).to.be.fulfilled
        })

        it('should REVERT if trying to crease base/base pool', async () => {
          await niftyswapFactoryContract.functions.createExchange(
            ownerERC1155Contract.address, 
            ownerERC1155Contract.address, 
            types[0]
          )
          
          // Retrieve exchange address
          let exchangeAddress2 = await niftyswapFactoryContract.functions.tokensToExchange(ownerERC1155Contract.address, ownerERC1155Contract.address, types[0])
      
          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, exchangeAddress2, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 50000000}
          )

          await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#_addLiquidity: BASE_POOL_FORBIDDEN"))
        })

        it('should REVERT if deadline is passed', async () => {
          let blocknumber = await userProvider.getBlockNumber()
          let addLiquidityData = getAddLiquidityData(baseAmountsToAdd, blocknumber)

          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: DEADLINE_EXCEEDED") )
        })

        it('should REVERT if a maxBaseToken is null', async () => {
          let baseAmountsToAdd = new Array(nTokenTypes).fill('').map((a, i) => baseAmountToAdd)
          baseAmountsToAdd[5] = new BigNumber(0)
          let addLiquidityData = getAddLiquidityData(baseAmountsToAdd, 10000000)

          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: NULL_MAX_BASE_TOKEN") )
        })

        it('should REVERT if a token amount is null', async () => {
          let tokenAmountsToAddCopy = [...tokenAmountsToAdd]
          tokenAmountsToAddCopy[5] = new BigNumber(0)

          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAddCopy, addLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: NULL_TOKENS_AMOUNT") )
        })

        it('should REVERT if arrays are not the same length', async () => {
          let baseAmount1 = baseAmountToAdd.add(1) 

          // If expected tier is larger, then should be fine
          let data = getAddLiquidityData([baseAmountToAdd, baseAmountToAdd, baseAmountToAdd], 10000000)
          const tx1 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1, 1], data, TX_PARAM)
          await expect(tx1).to.be.fulfilled;

          // Everything else should throw
          data = getAddLiquidityData([baseAmount1, baseAmount1], 10000000)
          const tx2 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1, 2], [1, 1, 1], data, TX_PARAM)
          await expect(tx2).to.be.rejectedWith(RevertError())
          
          data = getAddLiquidityData([baseAmount1, baseAmount1], 10000000)
          const tx3 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1, 1, 1], data, TX_PARAM)
          await expect(tx3).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

          data = getAddLiquidityData([baseAmount1], 10000000)
          const tx4 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1], data, TX_PARAM)
          await expect(tx4).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

          data = getAddLiquidityData([baseAmount1, baseAmount1], 10000000)
          const tx5 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1], data, TX_PARAM)
          await expect(tx5).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

          data = getAddLiquidityData([baseAmount1], 10000000)
          const tx6 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1, 1], data, TX_PARAM)
          await expect(tx6).to.be.rejectedWith(RevertError())
        })

        it('should REVERT if any duplicate', async () => {
          const tx1 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 1], [tokenAmountToAdd, tokenAmountToAdd], addLiquidityData,
            {gasLimit: 50000000}
          )
          await expect(tx1).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          const tx2 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 2, 2], [tokenAmountToAdd, tokenAmountToAdd, tokenAmountToAdd], addLiquidityData,
            {gasLimit: 50000000}
          )
          await expect(tx2).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          const tx3 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 2, 1], [tokenAmountToAdd, tokenAmountToAdd, tokenAmountToAdd], addLiquidityData,
            {gasLimit: 50000000}
          )
          await expect(tx3).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
        })

        context('When liquidity was added', () => {
          let tx;
          const baseAmountsToAddOne = new Array(nTokenTypes).fill('').map((a, i) => baseAmountToAdd.add(1))
          const addLiquidityDataOne = getAddLiquidityData(baseAmountsToAddOne, 10000000)

          beforeEach( async () => {
            tx = await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 50000000}
            )
          })
          
          it('should update Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await userERC1155Contract.functions.balanceOf(operatorAddress, types[i])

              expect(exchangeBalance).to.be.eql(tokenAmountToAdd)
              expect(operatorBalance).to.be.eql(new BigNumber(nTokensPerType).sub(tokenAmountToAdd))
            }
          })
      
          it('should update Base Token balances', async () => {
              const exchangeBalance = await userBaseTokenContract.functions.balanceOf(niftyswapExchangeContract.address, baseTokenID)
              const operatorBalance = await userBaseTokenContract.functions.balanceOf(operatorAddress, baseTokenID)

              expect(exchangeBalance).to.be.eql(baseAmountToAdd.mul(nTokenTypes))
              expect(operatorBalance).to.be.eql(new BigNumber(baseTokenAmount).sub(baseAmountToAdd.mul(nTokenTypes)))
          })

          it('should update the Base Tokens per token reserve', async () => {
            for (let i = 0; i < types.length; i++) {
              const reserve = await niftyswapExchangeContract.functions.getBaseTokenReserves([types[i]])
              expect(reserve[0]).to.be.eql(baseAmountToAdd)
            }
          })
      
          it('should update NiftySwap Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await niftyswapExchangeContract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await niftyswapExchangeContract.functions.balanceOf(operatorAddress, types[i])

              expect(exchangeBalance).to.be.eql(Zero)
              expect(operatorBalance).to.be.eql(new BigNumber(baseAmountToAdd))
            }
          })

          it('should update total supples for Niftyswap Token ids balances', async () => {
            const exchangeTotalSupplies = await niftyswapExchangeContract.functions.getTotalSupply(types)
            for (let i = 0; i < types.length; i++) {
              expect(exchangeTotalSupplies[i]).to.be.eql(new BigNumber(baseAmountToAdd))
            }
          })

          it('should DECREASE the BUY prices for 2ND deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 1st deposit
            const prePrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].gte(postPrices[i])).to.be.equal(true)
            }
          })

          it('should DECREASE the BUY prices for 3RD deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            // After 3rd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].gte(postPrices[i])).to.be.equal(true)
            }
          })

          it('should INCREASE the SELL prices for 2ND deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 1st deposit
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].lte(postPrices[i])).to.be.equal(true)
            }
          })

          it('should INCREASE the SELL prices for 3RD deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            // After 3rd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].lte(postPrices[i])).to.be.equal(true)
            }
          })

          it('should emit LiquidityAdded event', async () => {
            let filterFromOperatorContract: ethers.ethers.EventFilter

            // Get event filter to get internal tx event
            filterFromOperatorContract = niftyswapExchangeContract.filters.LiquidityAdded(null, null, null, null);

            // Get logs from internal transaction event
            // @ts-ignore (https://github.com/ethers-io/ethers.js/issues/204#issuecomment-427059031)
            filterFromOperatorContract.fromBlock = 0;
            let logs = await operatorProvider.getLogs(filterFromOperatorContract);
            expect(logs[0].topics[0]).to.be.eql(niftyswapExchangeContract.interface.events.LiquidityAdded.topic)
          })

        })

        context('When liquidity was added for the second time', () => {
          const baseAmountsToAddOne = new Array(nTokenTypes).fill('').map((a, i) => baseAmountToAdd.add(1))
          const addLiquidityDataOne = getAddLiquidityData(baseAmountsToAddOne, 10000000)

          beforeEach( async () => {
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 50000000}
            )
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
          })

          it('should REVERT if a maxBaseToken is exceeded', async () => {
            let baseAmountsToAdd = new Array(nTokenTypes).fill('').map((a, i) => baseAmountToAdd)
            baseAmountsToAdd[5] = new BigNumber(1000)
            let addLiquidityData = getAddLiquidityData(baseAmountsToAdd, 10000000)
      
            const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: MAX_BASE_TOKENS_EXCEEDED") )
          })
          
          it('should update Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await userERC1155Contract.functions.balanceOf(operatorAddress, types[i])

              expect(exchangeBalance).to.be.eql(tokenAmountToAdd.mul(2))
              expect(operatorBalance).to.be.eql((new BigNumber(nTokensPerType).sub(tokenAmountToAdd.mul(2))))
            }
          })
      
          it('should update Base Token balances', async () => {
              const operatorBalance1 = new BigNumber(baseTokenAmount).sub(baseAmountToAdd.mul(nTokenTypes))

              const exchangeBalance = await userBaseTokenContract.functions.balanceOf(niftyswapExchangeContract.address, baseTokenID)
              const operatorBalance = await userBaseTokenContract.functions.balanceOf(operatorAddress, baseTokenID)

              const baseReserve = baseAmountToAdd
              const tokenReserve = tokenAmountToAdd
              const baseTokenAmountCalc = (tokenAmountToAdd.mul(baseReserve)).div(tokenReserve)

              // .add(nTokenTypes) is to account for rounding error protection
              expect(exchangeBalance).to.be.eql(baseAmountToAdd.mul(nTokenTypes).add(baseTokenAmountCalc.mul(nTokenTypes).add(nTokenTypes)))
              expect(operatorBalance).to.be.eql(operatorBalance1.sub(baseTokenAmountCalc.mul(nTokenTypes).add(nTokenTypes)))
          })

          it('should update the Base Tokens per token reserve', async () => {
            for (let i = 0; i < types.length; i++) {
              const reserve = await niftyswapExchangeContract.functions.getBaseTokenReserves([types[i]])
              const newBaseTokenAmount = (tokenAmountToAdd.mul(baseAmountToAdd)).div(tokenAmountToAdd)

              // .add(1) is to account for rounding error protection
              expect(reserve[0]).to.be.eql(baseAmountToAdd.add(newBaseTokenAmount).add(1))
            }
          })
      
          it('should update NiftySwap Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await niftyswapExchangeContract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await niftyswapExchangeContract.functions.balanceOf(operatorAddress, types[i])

              const newBaseTokenAmount = (tokenAmountToAdd.mul(baseAmountToAdd)).div(tokenAmountToAdd)

              // .add(1) is to account for rounding error protection
              expect(operatorBalance).to.be.eql(new BigNumber(baseAmountToAdd).add(newBaseTokenAmount).add(1))
              expect(exchangeBalance).to.be.eql(Zero)
            }
          })

          it('should update total supples for Niftyswap Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeTotalSupply = await niftyswapExchangeContract.functions.getTotalSupply([types[i]])
              const newBaseTokenAmount = (tokenAmountToAdd.mul(baseAmountToAdd)).div(tokenAmountToAdd)

              // .add(1) is to account for rounding error protection
              expect(exchangeTotalSupply[0]).to.be.eql(new BigNumber(baseAmountToAdd).add(newBaseTokenAmount).add(1))
            }
          })

        })

        describe('When liquidity > 0', () => {
          beforeEach(async () => {
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 8000000}
            )
          })

          it('should pass when balances are sufficient', async () => {
            let maxBaseTokens: ethers.utils.BigNumber[] = []

            for (let i = 0; i < nTokenTypes; i++) {
              maxBaseTokens.push(baseAmountToAdd.mul(2))
            }
            let addLiquidityData2 = getAddLiquidityData(maxBaseTokens, 10000000)

            const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData2,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.fulfilled
          })
        })

      })

      describe('_removeLiquidity() function', () => {
        const nTokenTypesToRemove = 30;

        const tokenAmountToRemove = new BigNumber(75);
        const baseAmountToRemove = ((new BigNumber(10).pow(18)).mul(300)).div(4)
        
        const typesToRemove = new Array(nTokenTypesToRemove).fill('').map((a, i) => getBig(i))

        const tokenAmountsToRemove = new Array(nTokenTypesToRemove).fill('').map((a, i) => tokenAmountToRemove)
        const baseAmountsToRemove = new Array(nTokenTypesToRemove).fill('').map((a, i) => baseAmountToRemove)

        const niftyTokenToSend = new Array(nTokenTypesToRemove).fill('').map((a, i) => baseAmountToRemove)

        const removeLiquidityData: string = getRemoveLiquidityData(baseAmountsToRemove, tokenAmountsToRemove, 10000000)

        it('should revert if no Niftyswap token', async () => {
          const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith(RevertError("SafeMath#sub: UNDERFLOW"))
        })

        it('should revert if empty reserve', async () => {
          const zeroArray = new Array(nTokenTypesToRemove).fill('').map((a, i) => new BigNumber(0))
          const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, zeroArray, removeLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#_removeLiquidity: NULL_TOTAL_LIQUIDITY"))
        })


        context('When liquidity was added', () => {
          beforeEach( async () => {
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 50000000}
            )
          })


          it('should revert if insufficient base tokens', async () => {
            let baseAmountsToRemoveCopy = [...baseAmountsToRemove]
            baseAmountsToRemoveCopy[5] = new BigNumber(baseAmountsToRemoveCopy[5].mul(10000))
            let removeLiquidityData = getRemoveLiquidityData(baseAmountsToRemoveCopy, tokenAmountsToRemove, 10000000)

            const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#_removeLiquidity: INSUFFICIENT_BASE_TOKENS"))
          })

          it('should revert if insufficient tokens', async () => {
            let tokenAmountsToRemoveCopy = [...tokenAmountsToRemove]
            tokenAmountsToRemoveCopy[5] = new BigNumber(tokenAmountsToRemoveCopy[5].mul(10000))
            let removeLiquidityData = getRemoveLiquidityData(baseAmountsToRemove, tokenAmountsToRemoveCopy, 10000000)

            const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#_removeLiquidity: INSUFFICIENT_TOKENS"))
          })

          it('should fail if any duplicate', async () => {
            const tx1 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 1], [baseAmountToRemove, baseAmountToRemove], removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx1).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
      
            const tx2 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 2, 2], [baseAmountToRemove, baseAmountToRemove, baseAmountToRemove], removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx2).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
      
            const tx3 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 2, 1], [baseAmountToRemove, baseAmountToRemove, baseAmountToRemove], removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx3).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
          })

          it('should REVERT if arrays are not the same length', async () => {  
            // If expected tier is larger, then should be fine
            let data = getRemoveLiquidityData([baseAmountToRemove], [tokenAmountToRemove], 10000000)
            const tx1 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [baseAmountToRemove], data, TX_PARAM)
            await expect(tx1).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))
      
            // Everything else should throw
            data = getRemoveLiquidityData([baseAmountToRemove], [tokenAmountToRemove], 10000000)
            const tx2 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [2], [baseAmountToRemove, baseAmountToRemove], data, TX_PARAM)
            await expect(tx2).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([baseAmountToRemove, baseAmountToRemove], [tokenAmountToRemove], 10000000)
            const tx3 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [3], [baseAmountToRemove], data, TX_PARAM)
            await expect(tx3).to.be.fulfilled

            data = getRemoveLiquidityData([baseAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], 10000000)
            const tx4 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [4], [baseAmountToRemove], data, TX_PARAM)
            await expect(tx4).to.be.fulfilled

            data = getRemoveLiquidityData([baseAmountToRemove], [tokenAmountToRemove], 10000000)
            const tx5 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [5, 6], [baseAmountToRemove, baseAmountToRemove], data, TX_PARAM)
            await expect(tx5).to.be.rejectedWith(RevertError())

            data = getRemoveLiquidityData([baseAmountToRemove, baseAmountToRemove], [tokenAmountToRemove], 10000000)
            const tx6 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [7, 8], [baseAmountToRemove], data, TX_PARAM)
            await expect(tx6).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([baseAmountToRemove], [tokenAmountToRemove, baseAmountToRemove], 10000000)
            const tx7 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [9, 10], [baseAmountToRemove], data, TX_PARAM)
            await expect(tx7).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([baseAmountToRemove, baseAmountToRemove], [tokenAmountToRemove], 10000000)
            const tx8 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [11], [baseAmountToRemove, baseAmountToRemove], data, TX_PARAM)
            await expect(tx8).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([baseAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], 10000000)
            const tx9 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [12], [baseAmountToRemove, baseAmountToRemove], data, TX_PARAM)
            await expect(tx9).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([baseAmountToRemove, baseAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], 10000000)
            const tx10 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [13], [baseAmountToRemove], data, TX_PARAM)
            await expect(tx10).to.be.fulfilled

            data = getRemoveLiquidityData([baseAmountToRemove, baseAmountToRemove], [tokenAmountToRemove], 10000000)
            const tx11 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [14, 15], [baseAmountToRemove, baseAmountToRemove], data, TX_PARAM)
            await expect(tx11).to.be.rejectedWith(RevertError())

            data = getRemoveLiquidityData([baseAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], 10000000)
            const tx12 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [16, 17], [baseAmountToRemove, baseAmountToRemove], data, TX_PARAM)
            await expect(tx12).to.be.rejectedWith(RevertError())

            data = getRemoveLiquidityData([baseAmountToRemove, baseAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], 10000000)
            const tx13 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [18, 19], [baseAmountToRemove], data, TX_PARAM)
            await expect(tx13).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([baseAmountToRemove, baseAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], 10000000)
            const tx14 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [20], [baseAmountToRemove, baseAmountToRemove], data, TX_PARAM)
            await expect(tx14).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))
          })

          it('should PASS if enough Niftyswap token', async () => {
            const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.fulfilled
          })

          it('should INCREASE the BUY prices for 2ND withdraw', async () => {
            const ones = new Array(nTokenTypesToRemove).fill('').map((a, i) => 1)
            
            // After 1st deposit
            const prePrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].lte(postPrices[i])).to.be.equal(true)
            }
          })

          it('should INCREASE the BUY prices for 3RD withdraw', async () => {
            const ones = new Array(nTokenTypesToRemove).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            // After 3rd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_baseToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].lte(postPrices[i])).to.be.equal(true)
            }
          })

          it('should DECREASE the SELL prices for 2ND withdraw', async () => {
            const ones = new Array(nTokenTypesToRemove).fill('').map((a, i) => 1)
            
            // After 1st deposit
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].gte(postPrices[i])).to.be.equal(true)
            }
          })

          it('should DECREASE the SELL prices for 3RD withdraw', async () => {
            const ones = new Array(nTokenTypesToRemove).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            // After 3rd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToBase(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[i].gte(postPrices[i])).to.be.equal(true)
            }
          })

          context('When liquidity was removed', () => {
            let tx;
            beforeEach( async () => {
              tx = await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
                {gasLimit: 8000000}
              )
            })
            
            it('should update Token ids balances', async () => {
              const expectedVal = tokenAmountToAdd.sub(tokenAmountToRemove)
              for (let i = 0; i < types.length; i++) {
                const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
                const operatorBalance = await userERC1155Contract.functions.balanceOf(operatorAddress, types[i])

                expect(exchangeBalance).to.be.eql(new BigNumber(expectedVal))
                expect(operatorBalance).to.be.eql(new BigNumber(nTokensPerType).sub(expectedVal))
              }
            })
        
            it('should update Base Token balances', async () => {
              const expectedVal = baseAmountToAdd.mul(nTokenTypes).sub(baseAmountToRemove.mul(nTokenTypes))
              const exchangeBalance = await userBaseTokenContract.functions.balanceOf(niftyswapExchangeContract.address, baseTokenID)
              const operatorBalance = await userBaseTokenContract.functions.balanceOf(operatorAddress, baseTokenID)

              expect(exchangeBalance).to.be.eql(expectedVal)
              expect(operatorBalance).to.be.eql(baseTokenAmount.sub(expectedVal))
            })  

            it('should update the Base Tokens per token reserve', async () => {
              const expectedVal = baseAmountToAdd.sub(baseAmountToRemove)
              const reserves = await niftyswapExchangeContract.functions.getBaseTokenReserves(types)
              for (let i = 0; i < types.length; i++) {
                expect(reserves[i]).to.be.eql(expectedVal)
              }
            })
        
            it('should update NiftySwap Token ids balances', async () => {
              const expectedVal = baseAmountToAdd.sub(baseAmountToRemove)
              for (let i = 0; i < types.length; i++) {
                const exchangeBalance = await niftyswapExchangeContract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
                const operatorBalance = await niftyswapExchangeContract.functions.balanceOf(operatorAddress, types[i])

                expect(exchangeBalance).to.be.eql(Zero)
                expect(operatorBalance).to.be.eql(expectedVal)
              }
            })

            it('should update total supplies for Niftyswap Token ids balances', async () => {
              const expectedVal = baseAmountToAdd.sub(baseAmountToRemove)
              const exchangeTotalSupplies = await niftyswapExchangeContract.functions.getTotalSupply(types)
              for (let i = 0; i < types.length; i++) {
                expect(exchangeTotalSupplies[i]).to.be.eql(expectedVal)
              }
            })

            it('should emit LiquidityRemoved event', async () => {
              const receipt = await tx.wait(1)
              const ev = receipt.events!.pop()!
              expect(ev.event).to.be.eql('LiquidityRemoved')
            })

          })
        })
      })

      describe('_tokenToBase() function', () => {

        //Sell
        const tokenAmountToSell = new BigNumber(50)
        const tokensAmountsToSell: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToSell)
        let sellTokenData: string;

        beforeEach(async () => {
          // Add liquidity
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 30000000}
          )
          
          // Sell
          const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
          sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokenTypes), 10000000)
        })

        it('should fail if token balance is insufficient', async () => {
          await userERC1155Contract.functions.safeTransferFrom(userAddress, ownerAddress, types[0], nTokensPerType, [])
          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )
          if (condition[1] == 1 || condition[1] == 3){
            await expect(tx).to.be.rejectedWith( RevertError("SafeMath#sub: UNDERFLOW") )
          } else {
            await expect(tx).to.be.rejectedWith( RevertError(erc1155_error_prefix + "_viewUpdateBinValue: UNDERFLOW") )
          }
        })

        it('should fail if token sent is 0', async () => {
          let tokensAmountsToSellCopy = [...tokensAmountsToSell]
          tokensAmountsToSellCopy[0] = new BigNumber(0)
          
          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSellCopy, sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_tokenToBase: NULL_TOKENS_SOLD") )
        })

        it('should fail if deadline is passed', async () => {
          let blocknumber = await userProvider.getBlockNumber()
          const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
          let sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokenTypes), blocknumber)

          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_tokenToBase: DEADLINE_EXCEEDED") )
        })

        it('should pass if base token balance is equal to cost', async () => {
          const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
          let cost = price[0].mul(nTokenTypes)

          let sellTokenData = getSellTokenData(userAddress, cost, 10000000)

          console.log(1)
          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )
          console.log(2)
          await expect(tx).to.be.fulfilled
        })

        it('should fail if base token balance is lower than cost', async () => {
          const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
          let cost = price[0].mul(nTokenTypes)

          let sellTokenData = getSellTokenData(userAddress, cost.add(1), 10000000)

          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_tokenToBase: INSUFFICIENT_BASE_TOKENS") )
        })

        it('should fail if any duplicate', async () => {
          const tx1 = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, [1, 1], [tokenAmountToSell, tokenAmountToSell], sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx1).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          const tx2 = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, [1, 2, 2], [tokenAmountToSell, tokenAmountToSell, tokenAmountToSell], sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx2).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          const tx3 = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, [1, 2, 1], [tokenAmountToSell, tokenAmountToSell, tokenAmountToSell], sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx3).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
        })

        it('should REVERT if arrays are not the same length', async () => {
          const tx1 = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, [0, 1], [tokenAmountToSell], sellTokenData, TX_PARAM)
          await expect(tx1).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

          const tx2 = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, [0], [tokenAmountToSell, tokenAmountToSell], sellTokenData, TX_PARAM)
          await expect(tx2).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))
        })
        
        it('should sell tokens when balances are sufficient', async () => {
          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.fulfilled
        })

        describe('When trade is successful', async () => {
          let cost;
          let tx;

          beforeEach(async () => {
            const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
            cost = price[0].mul(nTokenTypes)

            tx = await userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
              {gasLimit: 8000000}
            )
          })

          it('should update Tokens balances if it passes', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

              expect(exchangeBalance).to.be.eql(tokenAmountToAdd.add(tokenAmountToSell))
              expect(userBalance).to.be.eql(new BigNumber(nTokensPerType).sub(tokenAmountToSell))
            }
          })
      
          it('should update Base Tokens balances if it passes', async () => {
            const exchangeBalance = await userBaseTokenContract.functions.balanceOf(niftyswapExchangeContract.address, baseTokenID)
            const userBalance = await userBaseTokenContract.functions.balanceOf(userAddress, baseTokenID)

            expect(exchangeBalance).to.be.eql(baseAmountToAdd.mul(nTokenTypes).sub(cost))
            expect(userBalance).to.be.eql(baseTokenAmount.add(cost))
          })

          it('should update the Base Tokens per token reserve', async () => {
            const reserves = await niftyswapExchangeContract.functions.getBaseTokenReserves(types)
            for (let i = 0; i < types.length; i++) {
              expect(reserves[i]).to.be.eql(baseAmountToAdd.sub(cost.div(nTokenTypes)))
            }
          })

          it('should have token sell price adjusted', async () => {
            const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);

            let soldAmountWithFee = tokenAmountToSell.mul(995)
            let baseReserve = baseAmountToAdd.sub(cost.div(nTokenTypes))
            let numerator = soldAmountWithFee.mul(baseReserve)
            let tokenReserveWithFee = (tokenAmountToAdd.add(tokenAmountToSell)).mul(1000)
            let denominator = tokenReserveWithFee.add(soldAmountWithFee)

            expect(price[0]).to.be.eql(numerator.div(denominator))
          })

          it('should emit BaseTokenPurchase event', async () => {
            let filterFromOperatorContract: ethers.ethers.EventFilter

            // Get event filter to get internal tx event
            filterFromOperatorContract = niftyswapExchangeContract.filters.BaseTokenPurchase(null, null, null, null, null);

            // Get logs from internal transaction event
            // @ts-ignore (https://github.com/ethers-io/ethers.js/issues/204#issuecomment-427059031)
            filterFromOperatorContract.fromBlock = 0;
            let logs = await operatorProvider.getLogs(filterFromOperatorContract);
            expect(logs[0].topics[0]).to.be.eql(niftyswapExchangeContract.interface.events.BaseTokenPurchase.topic)
          })

        })
      })

      describe('_baseToToken() function', () => {

        //Buy
        const tokenAmountToBuy = new BigNumber(50)
        const tokensAmountsToBuy: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToBuy)
        let buyTokenData: string;
        let cost: ethers.utils.BigNumber

        beforeEach(async () => {
          // Add liquidity
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 30000000}
          )

          // Sell
          cost = (await niftyswapExchangeContract.functions.getPrice_baseToToken([0], [tokenAmountToBuy]))[0];
          cost = cost.mul(nTokenTypes)
          buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuy, 10000000)
        })

        it('should fail if base balance is insufficient', async () => {
          await userBaseTokenContract.functions.safeTransferFrom(userAddress, ownerAddress, baseTokenID, baseTokenAmount, [])
          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("SafeMath#sub: UNDERFLOW") )
        })

        it('should fail if base token sent is 0', async () => {
          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, 0, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("SafeMath#sub: UNDERFLOW") )
        })

        it('should fail if a bought amount is 0', async () => {
          let tokensAmountsToBuyCopy = [...tokensAmountsToBuy]
          tokensAmountsToBuyCopy[0] = new BigNumber(0);
          let buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuyCopy, 10000000)

          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_baseToToken: NULL_TOKENS_BOUGHT") )
        })

        it('should fail if deadline is passed', async () => {
          let blocknumber = await userProvider.getBlockNumber()
          let buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuy, blocknumber)

          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_baseToToken: DEADLINE_EXCEEDED") )
        })

        it('should fail if base token sent is lower than cost', async () => {
          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost.sub(1), buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("SafeMath#sub: UNDERFLOW") )
        })

        it('should fail if any duplicate', async () => {

          let One = new BigNumber(1)

          // Tokens to buy
          let invalid_buyTokenData1 = getBuyTokenData(randomWallet.address, [1, 1], [One, One], 10000000)
          const tx1 = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, invalid_buyTokenData1,
            {gasLimit: 8000000}
          )

          await expect(tx1).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          // Tokens to buy
          let invalid_buyTokenData2 = getBuyTokenData(randomWallet.address, [1, 2, 2], [One, One, One], 10000000)
          const tx2 = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, invalid_buyTokenData2,
            {gasLimit: 8000000}
          )
          await expect(tx2).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          // Tokens to buy
          let invalid_buyTokenData3 = getBuyTokenData(randomWallet.address, [1, 2, 1], [One, One, One], 10000000)
          const tx3 = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, invalid_buyTokenData3,
            {gasLimit: 8000000}
          )
          await expect(tx3).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
        })

        it('should REVERT if arrays are not the same length', async () => {
          let data = getBuyTokenData(userAddress, [0, 1], [tokenAmountToBuy], 10000000)
          const tx1 = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, data, TX_PARAM)
          await expect(tx1).to.be.rejectedWith(RevertError())

          data = getBuyTokenData(userAddress, [0], [tokenAmountToBuy, tokenAmountToBuy], 10000000)
          const tx2 = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, data, TX_PARAM)
          await expect(tx2).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))
        })
        
        it('should buy tokens if base amount is sufficient', async () => {
          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.fulfilled
        })

        describe('When trade is successful', async () => {
          let tx;

          beforeEach(async () => {
            tx = await userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
              {gasLimit: 8000000}
            )
          })

          it('should update Tokens balances if it passes', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

              expect(exchangeBalance).to.be.eql(tokenAmountToAdd.sub(tokenAmountToBuy))
              expect(userBalance).to.be.eql(new BigNumber(nTokensPerType).add(tokenAmountToBuy))
            }
          })
      
          it('should update Base Tokens balances if it passes', async () => {
              const exchangeBalance = await userBaseTokenContract.functions.balanceOf(niftyswapExchangeContract.address, baseTokenID)
              const userBalance = await userBaseTokenContract.functions.balanceOf(userAddress, baseTokenID)

              expect(exchangeBalance).to.be.eql(baseAmountToAdd.mul(nTokenTypes).add(cost))
              expect(userBalance).to.be.eql(baseTokenAmount.sub(cost))
          })

          it('should update the Base Tokens per token reserve', async () => {
            const reserves = await niftyswapExchangeContract.functions.getBaseTokenReserves(types)
            for (let i = 0; i < types.length; i++) {
              expect(reserves[i]).to.be.eql( baseAmountToAdd.add(cost.div(nTokenTypes)))
            }
          })

          it('should have token sell price adjusted', async () => {
            const price = await niftyswapExchangeContract.functions.getPrice_baseToToken([0], [tokenAmountToBuy]);

            let baseReserve = baseAmountToAdd.add(cost.div(nTokenTypes))
            let tokenReserve = tokenAmountToAdd.sub(tokenAmountToBuy)

            let numerator = baseReserve.mul(tokenAmountToBuy).mul(1000)
            let denominator = (tokenReserve.sub(tokenAmountToBuy)).mul(995)

            expect(price[0]).to.be.eql(numerator.div(denominator).add(1))
          })

          it('should emit TokensPurchase event', async () => {
            let filterFromOperatorContract: ethers.ethers.EventFilter

            // Get event filter to get internal tx event
            filterFromOperatorContract = niftyswapExchangeContract.filters.TokensPurchase(null, null, null, null, null);

            // Get logs from internal transaction event
            // @ts-ignore (https://github.com/ethers-io/ethers.js/issues/204#issuecomment-427059031)
            filterFromOperatorContract.fromBlock = 0;
            let logs = await operatorProvider.getLogs(filterFromOperatorContract);
            expect(logs[0].topics[0]).to.be.eql(niftyswapExchangeContract.interface.events.TokensPurchase.topic)
          })
        })

        it('should send to non msg.sender if specified', async () => {
          cost = (await niftyswapExchangeContract.functions.getPrice_baseToToken([0], [tokenAmountToBuy]))[0];
          cost = cost.mul(nTokenTypes)
          buyTokenData = getBuyTokenData(randomWallet.address, types, tokensAmountsToBuy, 10000000)

          {gasLimit: 8000000}
          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
          )
          await expect(tx).to.be.fulfilled
          
          // Token bought by sender
          for (let i = 0; i < types.length; i++) {
            const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
            const randomBalance = await userERC1155Contract.functions.balanceOf(randomWallet.address, types[i])
            const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

            expect(exchangeBalance).to.be.eql(tokenAmountToAdd.sub(tokenAmountToBuy))
            expect(randomBalance).to.be.eql(tokenAmountToBuy)
            expect(userBalance).to.be.eql(new BigNumber(nTokensPerType))
          }

          const exchangeBaseBalance = await userBaseTokenContract.functions.balanceOf(niftyswapExchangeContract.address, baseTokenID)
          const randomBaseBalance = await userBaseTokenContract.functions.balanceOf(randomWallet.address, baseTokenID)
          const userBaseBalance = await userBaseTokenContract.functions.balanceOf(userAddress, baseTokenID)

          expect(exchangeBaseBalance).to.be.eql(baseAmountToAdd.mul(nTokenTypes).add(cost))
          expect(randomBaseBalance).to.be.eql(Zero)
          expect(userBaseBalance).to.be.eql(baseTokenAmount.sub(cost))
        })

        it('should send to msg.sender if 0x0 is specified as recipient', async () => {
          cost = (await niftyswapExchangeContract.functions.getPrice_baseToToken([0], [tokenAmountToBuy]))[0];
          cost = cost.mul(nTokenTypes)
          buyTokenData = getBuyTokenData(ZERO_ADDRESS, types, tokensAmountsToBuy, 10000000)

          const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.fulfilled
          
          // Token sold from sender
          for (let i = 0; i < types.length; i++) {
            const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
            const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

            expect(exchangeBalance).to.be.eql(tokenAmountToAdd.sub(tokenAmountToBuy))
            expect(userBalance).to.be.eql(new BigNumber(nTokensPerType).add(tokenAmountToBuy))
          }

          const exchangeBaseBalance = await userBaseTokenContract.functions.balanceOf(niftyswapExchangeContract.address, baseTokenID)
          const userBaseBalance = await userBaseTokenContract.functions.balanceOf(userAddress, baseTokenID)

          expect(exchangeBaseBalance).to.be.eql(baseAmountToAdd.mul(nTokenTypes).add(cost))
          expect(userBaseBalance).to.be.eql(baseTokenAmount.sub(cost))
        })
      })
    })
  })
})
