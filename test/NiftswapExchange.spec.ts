import * as ethers from 'ethers'

import { 
  AbstractContract, 
  expect,
  RevertError,
  getBuyTokenData,
  getSellTokenData,
  getAddLiquidityData,
  getRemoveLiquidityData
} from './utils'

import * as utils from './utils'

import { ERC1155Mock } from 'typings/contracts/ERC1155Mock'
import { ERC1155PackedBalanceMock } from 'typings/contracts/ERC1155PackedBalanceMock'
import { NiftyswapExchange } from 'typings/contracts/NiftyswapExchange'
import { NiftyswapFactory } from 'typings/contracts/NiftyswapFactory'
//@ts-ignore
import { abi as exchangeABI } from '../artifacts/contracts/exchange/NiftyswapExchange.sol/NiftyswapExchange.json'
import { BigNumber } from 'ethers'
import { web3 } from 'hardhat'

// init test wallets from package.json mnemonic

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

const getBig = (id: number) => BigNumber.from(id);

describe('NiftyswapExchange', () => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  let ownerAddress: string
  let userAddress: string
  let operatorAddress: string
  let erc1155Abstract: AbstractContract
  let erc1155PackedAbstract: AbstractContract
  let niftyswapFactoryAbstract: AbstractContract

  // ERC-1155 token
  let ownerERC1155Contract: ERC1155Mock
  let userERC1155Contract: ERC1155Mock
  let operatorERC1155Contract: ERC1155Mock

  // Currency
  let ownerCurrencyContract: ERC1155Mock
  let userCurrencyContract: ERC1155Mock
  let operatorCurrencyContract: ERC1155Mock

  let niftyswapFactoryContract: NiftyswapFactory
  let niftyswapExchangeContract: NiftyswapExchange
  let operatorExchangeContract: NiftyswapExchange

  // Token Param
  const nTokenTypes    = 30 //560
  const nTokensPerType = 500000

  // Currency Param
  const currencyID = 666;
  const currencyAmount = BigNumber.from(10000000).mul(BigNumber.from(10).pow(18))

  // Add liquidity data
  const tokenAmountToAdd = BigNumber.from(300);
  const currencyAmountToAdd = (BigNumber.from(10).pow(18)).mul(299)

  // Transactions parameters
  const TX_PARAM = {gasLimit: 5000000}

  const deadline = Math.floor(Date.now() / 1000) + 100000

  // Arrays
  const types = new Array(nTokenTypes).fill('').map((a, i) => getBig(i))
  const values = new Array(nTokenTypes).fill('').map((a, i) => nTokensPerType)
  const currencyAmountsToAdd: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => currencyAmountToAdd)
  const tokenAmountsToAdd: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToAdd)
  const addLiquidityData: string = getAddLiquidityData(currencyAmountsToAdd, deadline)

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

        // Deploy Currency Token contract
        if (condition[1] == 1 || condition[1] == 2) {
          ownerCurrencyContract = await erc1155Abstract.deploy(ownerWallet) as ERC1155Mock
        } else if (condition[1] == 3) {
          ownerCurrencyContract = await ownerERC1155Contract.connect(ownerSigner) as ERC1155Mock
        }
        userCurrencyContract = await ownerCurrencyContract.connect(userSigner) as ERC1155Mock
        operatorCurrencyContract = await ownerCurrencyContract.connect(operatorSigner) as ERC1155Mock

        // Deploy Niftyswap factory
        niftyswapFactoryContract = await niftyswapFactoryAbstract.deploy(ownerWallet) as NiftyswapFactory

        // Create exchange contract for the ERC-1155 token
        await niftyswapFactoryContract.functions.createExchange(
          ownerERC1155Contract.address, 
          ownerCurrencyContract.address, 
          currencyID
        )
        
        // Retrieve exchange address
        const exchangeAddress = (await niftyswapFactoryContract.functions.tokensToExchange(ownerERC1155Contract.address, ownerCurrencyContract.address, currencyID))[0]
        
        // Type exchange contract
        niftyswapExchangeContract = new ethers.Contract(exchangeAddress, exchangeABI, ownerWallet) as NiftyswapExchange
        operatorExchangeContract = niftyswapExchangeContract.connect(operatorSigner) as NiftyswapExchange

        // Mint Token to owner and user
        await ownerERC1155Contract.functions.batchMintMock(operatorAddress, types, values, [])
        await ownerERC1155Contract.functions.batchMintMock(userAddress, types, values, [])

        // Mint Currency token to owner and user
        await ownerCurrencyContract.functions.mintMock(operatorAddress, currencyID, currencyAmount, [])
        await ownerCurrencyContract.functions.mintMock(userAddress, currencyID, currencyAmount, [])

        // Authorize Niftyswap to transfer funds on your behalf for addLiquidity & transfers
        await operatorCurrencyContract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
        await operatorERC1155Contract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
        await userCurrencyContract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
        await userERC1155Contract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
      })

      describe('Getter functions', () => {
        describe('getTokenAddress() function', () => {
          it('should return token address', async () => {
            const token_address = await niftyswapExchangeContract.functions.getTokenAddress()
            await expect(token_address[0]).to.be.eql(ownerERC1155Contract.address)
          })
        })

        describe('getCurrencyInfo() function', () => {
          it('should return currency token address and ID', async () => {
            const token_info = await niftyswapExchangeContract.functions.getCurrencyInfo()
            await expect(token_info[0]).to.be.eql(ownerCurrencyContract.address)
            await expect(token_info[1]).to.be.eql(BigNumber.from(currencyID))
          })
        })

        describe('getBuyPrice() function', () => {
          it('should round UP', async () => {
            let bought_amount = 100
            let numerator = 1500
            let denominator = 751
            const price = await niftyswapExchangeContract.functions.getBuyPrice(bought_amount, numerator, denominator)
            expect(price[0]).to.be.eql(BigNumber.from(232)) // instead of 231.5726095917375
          })
        })

        describe('getSellPrice() function', () => {
          it('should round DOWN', async () => {
            let numerator = 1500
            let denominator = 751
            let bought_amount = 100
            const price = await niftyswapExchangeContract.functions.getSellPrice(bought_amount, denominator, numerator)
            expect(price.price).to.be.eql(BigNumber.from(175)) // instead of 175.48500881834215
          })
        })

        describe('getFactoryAddress() function', () => {
          it('should return factory address', async () => {
            const factory_address = await niftyswapExchangeContract.functions.getFactoryAddress()
            await expect(factory_address[0]).to.be.eql(niftyswapFactoryContract.address)
          })
        })

        describe('supportsInterface()', () => {
          it('should return true for 0x01ffc9a7 (IERC165)', async () => {
            const support = await niftyswapExchangeContract.functions.supportsInterface('0x01ffc9a7')
            expect(support[0]).to.be.eql(true)
          })
    
          it('should return true for 0x4e2312e0 (IERC1155Receiver)', async () => {
            const support = await niftyswapExchangeContract.functions.supportsInterface('0x4e2312e0')
            expect(support[0]).to.be.eql(true)
          })
  
          it('should return true for 0xd9b67a26 (IERC1155)', async () => {
            const support = await niftyswapExchangeContract.functions.supportsInterface('0xd9b67a26')
            expect(support[0]).to.be.eql(true)
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

        it('should ROUND UP the currency amount to be deposited on second deposit', async () => {
          let addLiquidityData1 = getAddLiquidityData([BigNumber.from(1000000001)], deadline)
          let tokenAmountsToAdd1 = [BigNumber.from(2)]

          // After 2nd deposit
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0], tokenAmountsToAdd1, addLiquidityData1,
            {gasLimit: 50000000}
          )

          let reserve1 = (await niftyswapExchangeContract.functions.getCurrencyReserves([0]))[0]
          expect(reserve1[0]).to.be.eql(BigNumber.from(1000000001)) 

          let addLiquidityData2 = getAddLiquidityData([BigNumber.from(1000000001)], deadline)
          let tokenAmountsToAdd2 = [BigNumber.from(1)] // 1 less

          // After 2nd deposit
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0], tokenAmountsToAdd2, addLiquidityData2,
            {gasLimit: 50000000}
          )

          let reserve2 = (await niftyswapExchangeContract.functions.getCurrencyReserves([0]))[0]
          expect(reserve2[0]).to.be.eql(BigNumber.from(1500000002)) // Should be 1500000001.5
        })

        it('should ROUND DOWN the amount of liquidity to mint on second deposit', async () => {
          let addLiquidityData1 = getAddLiquidityData([BigNumber.from(1000000001)], deadline)
          let tokenAmountsToAdd1 = [BigNumber.from(2)]

          // first deposit
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0], tokenAmountsToAdd1, addLiquidityData1,
            {gasLimit: 50000000}
          )

          let liquidity_supply1 = (await niftyswapExchangeContract.functions.getTotalSupply([0]))[0]
          expect(liquidity_supply1[0]).to.be.eql(BigNumber.from(1000000001))

          let addLiquidityData2 = getAddLiquidityData([BigNumber.from(1000000001)], deadline)
          let tokenAmountsToAdd2 = [BigNumber.from(1)] // 1 less

          // After 2nd deposit
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0], tokenAmountsToAdd2, addLiquidityData2,
            {gasLimit: 50000000}
          )

          let liquidity_supply2 = (await niftyswapExchangeContract.functions.getTotalSupply([0]))[0]
          expect(liquidity_supply2[0]).to.be.eql(BigNumber.from(1500000001)) // Should be 1500000001.5
        })

        it('should REVERT if trying to crease currency/currency pool', async () => {
          await niftyswapFactoryContract.functions.createExchange(
            ownerERC1155Contract.address, 
            ownerERC1155Contract.address, 
            types[0]
          )
          
          // Retrieve exchange address
          let exchangeAddress2 = await niftyswapFactoryContract.functions.tokensToExchange(ownerERC1155Contract.address, ownerERC1155Contract.address, types[0])
      
          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, exchangeAddress2[0], types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 50000000}
          )

          await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#_addLiquidity: CURRENCY_POOL_FORBIDDEN"))
        })

        it('should REVERT if deadline is passed', async () => {
          let timestamp = Math.floor(Date.now() / 1000) - 1
          let addLiquidityData = getAddLiquidityData(currencyAmountsToAdd, timestamp)

          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: DEADLINE_EXCEEDED") )
        })

        it('should REVERT if a maxCurrency is null', async () => {
          let currencyAmountsToAdd = new Array(nTokenTypes).fill('').map((a, i) => currencyAmountToAdd)
          currencyAmountsToAdd[5] = BigNumber.from(0)
          let addLiquidityData = getAddLiquidityData(currencyAmountsToAdd, deadline)

          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: NULL_MAX_CURRENCY") )
        })

        it('should REVERT if a token amount is null', async () => {
          let tokenAmountsToAddCopy = [...tokenAmountsToAdd]
          tokenAmountsToAddCopy[5] = BigNumber.from(0)

          const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAddCopy, addLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: NULL_TOKENS_AMOUNT") )
        })

        it('should REVERT if arrays are not the same length', async () => {
          let currencyAmount1 = currencyAmountToAdd.add(1) 

          // If expected tier is larger, then should be fine
          let data = getAddLiquidityData([currencyAmountToAdd, currencyAmountToAdd, currencyAmountToAdd], deadline)
          const tx1 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1, 1], data, TX_PARAM)
          await expect(tx1).to.be.fulfilled;

          // Everything else should throw
          data = getAddLiquidityData([currencyAmount1, currencyAmount1], deadline)
          const tx2 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1, 2], [1, 1, 1], data, TX_PARAM)
          await expect(tx2).to.be.rejectedWith(RevertError())
          
          data = getAddLiquidityData([currencyAmount1, currencyAmount1], deadline)
          const tx3 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1, 1, 1], data, TX_PARAM)
          await expect(tx3).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

          data = getAddLiquidityData([currencyAmount1], deadline)
          const tx4 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1], data, TX_PARAM)
          await expect(tx4).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

          data = getAddLiquidityData([currencyAmount1, currencyAmount1], deadline)
          const tx5 = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [1], data, TX_PARAM)
          await expect(tx5).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

          data = getAddLiquidityData([currencyAmount1], deadline)
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
          const currencyAmountsToAddOne = new Array(nTokenTypes).fill('').map((a, i) => currencyAmountToAdd.add(1))
          const addLiquidityDataOne = getAddLiquidityData(currencyAmountsToAddOne, deadline)

          beforeEach( async () => {
            tx = await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 50000000}
            )
          })
          
          it('should update Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await userERC1155Contract.functions.balanceOf(operatorAddress, types[i])

              expect(exchangeBalance[0]).to.be.eql(tokenAmountToAdd)
              expect(operatorBalance[0]).to.be.eql(BigNumber.from(nTokensPerType).sub(tokenAmountToAdd))
            }
          })
      
          it('should update currency balances', async () => {
              const exchangeBalance = await userCurrencyContract.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
              const operatorBalance = await userCurrencyContract.functions.balanceOf(operatorAddress, currencyID)

              expect(exchangeBalance[0]).to.be.eql(currencyAmountToAdd.mul(nTokenTypes))
              expect(operatorBalance[0]).to.be.eql(BigNumber.from(currencyAmount).sub(currencyAmountToAdd.mul(nTokenTypes)))
          })

          it('should update the currency per token reserve', async () => {
            for (let i = 0; i < types.length; i++) {
              const reserve = await niftyswapExchangeContract.functions.getCurrencyReserves([types[i]])
              expect(reserve[0][0]).to.be.eql(currencyAmountToAdd)
            }
          })
      
          it('should update NiftySwap Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await niftyswapExchangeContract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await niftyswapExchangeContract.functions.balanceOf(operatorAddress, types[i])

              expect(exchangeBalance[0]).to.be.eql(ethers.constants.Zero)
              expect(operatorBalance[0]).to.be.eql(BigNumber.from(currencyAmountToAdd))
            }
          })

          it('should update total supplies for Niftyswap Token ids balances', async () => {
            const exchangeTotalSupplies = await niftyswapExchangeContract.functions.getTotalSupply(types)
            for (let i = 0; i < types.length; i++) {
              expect(exchangeTotalSupplies[0][i]).to.be.eql(BigNumber.from(currencyAmountToAdd))
            }
          })

          it('should DECREASE the BUY prices for 2ND deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 1st deposit
            const prePrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].gte(postPrices[0][i])).to.be.equal(true)
            }
          })

          it('should DECREASE the BUY prices for 3RD deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            // After 3rd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].gte(postPrices[0][i])).to.be.equal(true)
            }
          })

          it('should INCREASE the SELL prices for 2ND deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 1st deposit
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].lte(postPrices[0][i])).to.be.equal(true)
            }
          })

          it('should INCREASE the SELL prices for 3RD deposit', async () => {
            const ones = new Array(nTokenTypes).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            // After 3rd deposit
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].lte(postPrices[0][i])).to.be.equal(true)
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
            expect(logs[0].topics[0]).to.be.eql(niftyswapExchangeContract.interface.getEventTopic(niftyswapExchangeContract.interface.events["LiquidityAdded(address,uint256[],uint256[],uint256[])"]))
          })

        })

        context('When liquidity was added for the second time', () => {
          const currencyAmountsToAddOne = new Array(nTokenTypes).fill('').map((a, i) => currencyAmountToAdd.add(1))
          const addLiquidityDataOne = getAddLiquidityData(currencyAmountsToAddOne, deadline)

          beforeEach( async () => {
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 50000000}
            )
            await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityDataOne,
              {gasLimit: 50000000}
            )
          })

          it('should REVERT if a maxCurrency is exceeded', async () => {
            let currencyAmountsToAdd = new Array(nTokenTypes).fill('').map((a, i) => currencyAmountToAdd)
            currencyAmountsToAdd[5] = BigNumber.from(1000)
            let addLiquidityData = getAddLiquidityData(currencyAmountsToAdd, deadline)
      
            const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_addLiquidity: MAX_CURRENCY_AMOUNT_EXCEEDED") )
          })
          
          it('should update Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await userERC1155Contract.functions.balanceOf(operatorAddress, types[i])

              expect(exchangeBalance[0]).to.be.eql(tokenAmountToAdd.mul(2))
              expect(operatorBalance[0]).to.be.eql((BigNumber.from(nTokensPerType).sub(tokenAmountToAdd.mul(2))))
            }
          })
      
          it('should update currency balances', async () => {
              const operatorBalance1 = BigNumber.from(currencyAmount).sub(currencyAmountToAdd.mul(nTokenTypes))

              const exchangeBalance = await userCurrencyContract.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
              const operatorBalance = await userCurrencyContract.functions.balanceOf(operatorAddress, currencyID)

              const currencyReserve = currencyAmountToAdd
              const tokenReserve = tokenAmountToAdd
              const currencyAmountCalc = (tokenAmountToAdd.mul(currencyReserve)).div(tokenReserve)

              // .add(nTokenTypes) is to account for rounding error compensation
              expect(exchangeBalance[0]).to.be.eql(currencyAmountToAdd.mul(nTokenTypes).add(currencyAmountCalc.mul(nTokenTypes)))
              expect(operatorBalance[0]).to.be.eql(operatorBalance1.sub(currencyAmountCalc.mul(nTokenTypes)))
          })

          it('should update the currency amount per token reserve', async () => {
            for (let i = 0; i < types.length; i++) {
              const reserve = await niftyswapExchangeContract.functions.getCurrencyReserves([types[i]])
              const newCurrencyAmount = (tokenAmountToAdd.mul(currencyAmountToAdd)).div(tokenAmountToAdd)

              // .add(1) is to account for rounding error protection
              expect(reserve[0][0]).to.be.eql(currencyAmountToAdd.add(newCurrencyAmount))
            }
          })
      
          it('should update NiftySwap Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await niftyswapExchangeContract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const operatorBalance = await niftyswapExchangeContract.functions.balanceOf(operatorAddress, types[i])

              const newCurrencyAmount = (tokenAmountToAdd.mul(currencyAmountToAdd)).div(tokenAmountToAdd)

              // .add(1) is to account for rounding error protection
              expect(operatorBalance[0]).to.be.eql(BigNumber.from(currencyAmountToAdd).add(newCurrencyAmount))
              expect(exchangeBalance[0]).to.be.eql(ethers.constants.Zero)
            }
          })

          it('should update total supples for Niftyswap Token ids balances', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeTotalSupply = await niftyswapExchangeContract.functions.getTotalSupply([types[i]])
              const newCurrencyAmount = (tokenAmountToAdd.mul(currencyAmountToAdd)).div(tokenAmountToAdd)

              // .add(1) is to account for rounding error protection
              expect(exchangeTotalSupply[0][0]).to.be.eql(BigNumber.from(currencyAmountToAdd).add(newCurrencyAmount))
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
            let maxCurrency: BigNumber[] = []

            for (let i = 0; i < nTokenTypes; i++) {
              maxCurrency.push(currencyAmountToAdd.mul(2))
            }
            let addLiquidityData2 = getAddLiquidityData(maxCurrency, deadline)

            const tx = operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData2,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.fulfilled
          })
        })

      })

      describe('_removeLiquidity() function', () => {
        const nTokenTypesToRemove = 30;

        const tokenAmountToRemove = BigNumber.from(75);
        const currencyAmountToRemove = ((BigNumber.from(10).pow(18)).mul(299)).div(4)
        
        const typesToRemove = new Array(nTokenTypesToRemove).fill('').map((a, i) => getBig(i))

        const tokenAmountsToRemove = new Array(nTokenTypesToRemove).fill('').map((a, i) => tokenAmountToRemove)
        const currencyAmountsToRemove = new Array(nTokenTypesToRemove).fill('').map((a, i) => currencyAmountToRemove)

        const niftyTokenToSend = new Array(nTokenTypesToRemove).fill('').map((a, i) => currencyAmountToRemove)

        const removeLiquidityData: string = getRemoveLiquidityData(currencyAmountsToRemove, tokenAmountsToRemove, deadline)

        it('should revert if no Niftyswap token', async () => {
          const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith(RevertError("SafeMath#sub: UNDERFLOW"))
        })

        it('should revert if empty reserve', async () => {
          const zeroArray = new Array(nTokenTypesToRemove).fill('').map((a, i) => BigNumber.from(0))
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


          it('should revert if insufficient currency', async () => {
            let currencyAmountsToRemoveCopy = [...currencyAmountsToRemove]
            currencyAmountsToRemoveCopy[5] = BigNumber.from(currencyAmountsToRemoveCopy[5].mul(10000))
            let removeLiquidityData = getRemoveLiquidityData(currencyAmountsToRemoveCopy, tokenAmountsToRemove, deadline)

            const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#_removeLiquidity: INSUFFICIENT_CURRENCY_AMOUNT"))
          })

          it('should revert if insufficient tokens', async () => {
            let tokenAmountsToRemoveCopy = [...tokenAmountsToRemove]
            tokenAmountsToRemoveCopy[5] = BigNumber.from(tokenAmountsToRemoveCopy[5].mul(10000))
            let removeLiquidityData = getRemoveLiquidityData(currencyAmountsToRemove, tokenAmountsToRemoveCopy, deadline)

            const tx = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx).to.be.rejectedWith(RevertError("NiftyswapExchange#_removeLiquidity: INSUFFICIENT_TOKENS"))
          })

          it('should fail if any duplicate', async () => {
            const tx1 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 1], [currencyAmountToRemove, currencyAmountToRemove], removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx1).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
      
            const tx2 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 2, 2], [currencyAmountToRemove, currencyAmountToRemove, currencyAmountToRemove], removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx2).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
      
            const tx3 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [1, 2, 1], [currencyAmountToRemove, currencyAmountToRemove, currencyAmountToRemove], removeLiquidityData,
              {gasLimit: 8000000}
            )
            await expect(tx3).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
          })

          it('should REVERT if arrays are not the same length', async () => {  
            // If expected tier is larger, then should be fine
            let data = getRemoveLiquidityData([currencyAmountToRemove], [tokenAmountToRemove], deadline)
            const tx1 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [0, 1], [currencyAmountToRemove], data, TX_PARAM)
            await expect(tx1).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))
      
            // Everything else should throw
            data = getRemoveLiquidityData([currencyAmountToRemove], [tokenAmountToRemove], deadline)
            const tx2 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [2], [currencyAmountToRemove, currencyAmountToRemove], data, TX_PARAM)
            await expect(tx2).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([currencyAmountToRemove, currencyAmountToRemove], [tokenAmountToRemove], deadline)
            const tx3 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [3], [currencyAmountToRemove], data, TX_PARAM)
            await expect(tx3).to.be.fulfilled

            data = getRemoveLiquidityData([currencyAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], deadline)
            const tx4 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [4], [currencyAmountToRemove], data, TX_PARAM)
            await expect(tx4).to.be.fulfilled

            data = getRemoveLiquidityData([currencyAmountToRemove], [tokenAmountToRemove], deadline)
            const tx5 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [5, 6], [currencyAmountToRemove, currencyAmountToRemove], data, TX_PARAM)
            await expect(tx5).to.be.rejectedWith(RevertError())

            data = getRemoveLiquidityData([currencyAmountToRemove, currencyAmountToRemove], [tokenAmountToRemove], deadline)
            const tx6 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [7, 8], [currencyAmountToRemove], data, TX_PARAM)
            await expect(tx6).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([currencyAmountToRemove], [tokenAmountToRemove, currencyAmountToRemove], deadline)
            const tx7 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [9, 10], [currencyAmountToRemove], data, TX_PARAM)
            await expect(tx7).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([currencyAmountToRemove, currencyAmountToRemove], [tokenAmountToRemove], deadline)
            const tx8 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [11], [currencyAmountToRemove, currencyAmountToRemove], data, TX_PARAM)
            await expect(tx8).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([currencyAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], deadline)
            const tx9 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [12], [currencyAmountToRemove, currencyAmountToRemove], data, TX_PARAM)
            await expect(tx9).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([currencyAmountToRemove, currencyAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], deadline)
            const tx10 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [13], [currencyAmountToRemove], data, TX_PARAM)
            await expect(tx10).to.be.fulfilled

            data = getRemoveLiquidityData([currencyAmountToRemove, currencyAmountToRemove], [tokenAmountToRemove], deadline)
            const tx11 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [14, 15], [currencyAmountToRemove, currencyAmountToRemove], data, TX_PARAM)
            await expect(tx11).to.be.rejectedWith(RevertError())

            data = getRemoveLiquidityData([currencyAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], deadline)
            const tx12 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [16, 17], [currencyAmountToRemove, currencyAmountToRemove], data, TX_PARAM)
            await expect(tx12).to.be.rejectedWith(RevertError())

            data = getRemoveLiquidityData([currencyAmountToRemove, currencyAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], deadline)
            const tx13 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [18, 19], [currencyAmountToRemove], data, TX_PARAM)
            await expect(tx13).to.be.rejectedWith(RevertError("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))

            data = getRemoveLiquidityData([currencyAmountToRemove, currencyAmountToRemove], [tokenAmountToRemove, tokenAmountToRemove], deadline)
            const tx14 = operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, [20], [currencyAmountToRemove, currencyAmountToRemove], data, TX_PARAM)
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
            const prePrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].lte(postPrices[0][i])).to.be.equal(true)
            }
          })

          it('should INCREASE the BUY prices for 3RD withdraw', async () => {
            const ones = new Array(nTokenTypesToRemove).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            // After 3rd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_currencyToToken(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].lte(postPrices[0][i])).to.be.equal(true)
            }
          })

          it('should DECREASE the SELL prices for 2ND withdraw', async () => {
            const ones = new Array(nTokenTypesToRemove).fill('').map((a, i) => 1)
            
            // After 1st deposit
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].gte(postPrices[0][i])).to.be.equal(true)
            }
          })

          it('should DECREASE the SELL prices for 3RD withdraw', async () => {
            const ones = new Array(nTokenTypesToRemove).fill('').map((a, i) => 1)
            
            // After 2nd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const prePrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            // After 3rd deposit
            await operatorExchangeContract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, typesToRemove, niftyTokenToSend, removeLiquidityData,
              {gasLimit: 8000000}
            )
            const postPrices = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency(types, ones)

            for (let i = 0; i < types.length; i++) {
              expect(prePrices[0][i].gte(postPrices[0][i])).to.be.equal(true)
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

                expect(exchangeBalance[0]).to.be.eql(BigNumber.from(expectedVal))
                expect(operatorBalance[0]).to.be.eql(BigNumber.from(nTokensPerType).sub(expectedVal))
              }
            })
        
            it('should update currency balances', async () => {
              const expectedVal = currencyAmountToAdd.mul(nTokenTypes).sub(currencyAmountToRemove.mul(nTokenTypes))
              const exchangeBalance = await userCurrencyContract.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
              const operatorBalance = await userCurrencyContract.functions.balanceOf(operatorAddress, currencyID)

              expect(exchangeBalance[0]).to.be.eql(expectedVal)
              expect(operatorBalance[0]).to.be.eql(currencyAmount.sub(expectedVal))
            })  

            it('should update the currency amount per token reserve', async () => {
              const expectedVal = currencyAmountToAdd.sub(currencyAmountToRemove)
              const reserves = await niftyswapExchangeContract.functions.getCurrencyReserves(types)
              for (let i = 0; i < types.length; i++) {
                expect(reserves[0][i]).to.be.eql(expectedVal)
              }
            })
        
            it('should update NiftySwap Token ids balances', async () => {
              const expectedVal = currencyAmountToAdd.sub(currencyAmountToRemove)
              for (let i = 0; i < types.length; i++) {
                const exchangeBalance = await niftyswapExchangeContract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
                const operatorBalance = await niftyswapExchangeContract.functions.balanceOf(operatorAddress, types[i])

                expect(exchangeBalance[0]).to.be.eql(ethers.constants.Zero)
                expect(operatorBalance[0]).to.be.eql(expectedVal)
              }
            })

            it('should update total supplies for Niftyswap Token ids balances', async () => {
              const expectedVal = currencyAmountToAdd.sub(currencyAmountToRemove)
              const exchangeTotalSupplies = await niftyswapExchangeContract.functions.getTotalSupply(types)
              for (let i = 0; i < types.length; i++) {
                expect(exchangeTotalSupplies[0][i]).to.be.eql(expectedVal)
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

      describe('_tokenToCurrency() function', () => {

        //Sell
        const tokenAmountToSell = BigNumber.from(50)
        const tokensAmountsToSell: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToSell)
        let sellTokenData: string;

        beforeEach(async () => {
          // Add liquidity
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 30000000}
          )
          
          // Sell
          const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0];
          sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokenTypes), deadline)
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
          tokensAmountsToSellCopy[0] = BigNumber.from(0)
          
          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSellCopy, sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_tokenToCurrency: NULL_TOKENS_SOLD") )
        })

        it('should fail if deadline is passed', async () => {
          let timestamp = Math.floor(Date.now() / 1000) - 1
          const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0];
          let sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokenTypes), timestamp)

          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )

          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_tokenToCurrency: DEADLINE_EXCEEDED") )
        })

        it('should pass if currency balance is equal to cost', async () => {
          const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0];
          let cost = price[0].mul(nTokenTypes)

          let sellTokenData = getSellTokenData(userAddress, cost, deadline)

          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.fulfilled
        })

        it('should fail if currency balance is lower than cost', async () => {
          const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0];
          let cost = price[0].mul(nTokenTypes)

          let sellTokenData = getSellTokenData(userAddress, cost.add(1), deadline)

          const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_tokenToCurrency: INSUFFICIENT_CURRENCY_AMOUNT") )
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
            const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0];
            cost = price[0].mul(nTokenTypes)

            tx = await userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, types, tokensAmountsToSell, sellTokenData,
              {gasLimit: 8000000}
            )
          })

          it('should update Tokens balances if it passes', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

              expect(exchangeBalance[0]).to.be.eql(tokenAmountToAdd.add(tokenAmountToSell))
              expect(userBalance[0]).to.be.eql(BigNumber.from(nTokensPerType).sub(tokenAmountToSell))
            }
          })
      
          it('should update currency balances if it passes', async () => {
            const exchangeBalance = await userCurrencyContract.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
            const userBalance = await userCurrencyContract.functions.balanceOf(userAddress, currencyID)

            expect(exchangeBalance[0]).to.be.eql(currencyAmountToAdd.mul(nTokenTypes).sub(cost))
            expect(userBalance[0]).to.be.eql(currencyAmount.add(cost))
          })

          it('should update the currency amounts per token reserve', async () => {
            const reserves = await niftyswapExchangeContract.functions.getCurrencyReserves(types)
            for (let i = 0; i < types.length; i++) {
              expect(reserves[0][i]).to.be.eql(currencyAmountToAdd.sub(cost.div(nTokenTypes)))
            }
          })

          it('should have token sell price adjusted', async () => {
            const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0];

            let soldAmountWithFee = tokenAmountToSell.mul(995)
            let currencyReserve = currencyAmountToAdd.sub(cost.div(nTokenTypes))
            let numerator = soldAmountWithFee.mul(currencyReserve)
            let tokenReserveWithFee = (tokenAmountToAdd.add(tokenAmountToSell)).mul(1000)
            let denominator = tokenReserveWithFee.add(soldAmountWithFee)

            expect(price[0]).to.be.eql(numerator.div(denominator))
          })

          it('should emit CurrencyPurchase event', async () => {
            let filterFromOperatorContract: ethers.ethers.EventFilter

            // Get event filter to get internal tx event
            filterFromOperatorContract = niftyswapExchangeContract.filters.CurrencyPurchase(null, null, null, null, null);

            // Get logs from internal transaction event
            // @ts-ignore (https://github.com/ethers-io/ethers.js/issues/204#issuecomment-427059031)
            filterFromOperatorContract.fromBlock = 0;
            let logs = await operatorProvider.getLogs(filterFromOperatorContract);
            expect(logs[0].topics[0]).to.be.eql(
              niftyswapExchangeContract.interface.getEventTopic(
                niftyswapExchangeContract.interface.events[
                  "CurrencyPurchase(address,address,uint256[],uint256[],uint256[])"
                ]
              )
            )
          })

        })
      })

      describe('_currencyToToken() function', () => {

        //Buy
        const tokenAmountToBuy = BigNumber.from(50)
        const tokensAmountsToBuy: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToBuy)
        let buyTokenData: string;
        let cost: BigNumber

        beforeEach(async () => {
          // Add liquidity
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 30000000}
          )

          // Sell
          cost = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([0], [tokenAmountToBuy]))[0][0];
          cost = cost.mul(nTokenTypes)
          buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuy, deadline)
        })

        it('should fail if currency balance is insufficient', async () => {
          await userCurrencyContract.functions.safeTransferFrom(userAddress, ownerAddress, currencyID, currencyAmount, [])
          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("SafeMath#sub: UNDERFLOW") )
        })

        it('should fail if currency sent is 0', async () => {
          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, 0, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("SafeMath#sub: UNDERFLOW") )
        })

        it('should fail if a bought amount is 0', async () => {
          let tokensAmountsToBuyCopy = [...tokensAmountsToBuy]
          tokensAmountsToBuyCopy[0] = BigNumber.from(0);
          let buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuyCopy, deadline)

          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_currencyToToken: NULL_TOKENS_BOUGHT") )
        })

        it('should fail if deadline is passed', async () => {
          let timestamp = Math.floor(Date.now() / 1000) - 1
          let buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuy, timestamp)

          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
            {gasLimit: 8000000}
          )

          await expect(tx).to.be.rejectedWith( RevertError("NiftyswapExchange#_currencyToToken: DEADLINE_EXCEEDED") )
        })

        it('should fail if currency sent is lower than cost', async () => {
          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost.sub(1), buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.rejectedWith( RevertError("SafeMath#sub: UNDERFLOW") )
        })

        it('should fail if any duplicate', async () => {

          let One = BigNumber.from(1)

          // Tokens to buy
          let invalid_buyTokenData1 = getBuyTokenData(randomWallet.address, [1, 1], [One, One], deadline)
          const tx1 = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, invalid_buyTokenData1,
            {gasLimit: 8000000}
          )

          await expect(tx1).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          // Tokens to buy
          let invalid_buyTokenData2 = getBuyTokenData(randomWallet.address, [1, 2, 2], [One, One, One], deadline)
          const tx2 = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, invalid_buyTokenData2,
            {gasLimit: 8000000}
          )
          await expect(tx2).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )

          // Tokens to buy
          let invalid_buyTokenData3 = getBuyTokenData(randomWallet.address, [1, 2, 1], [One, One, One], deadline)
          const tx3 = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, invalid_buyTokenData3,
            {gasLimit: 8000000}
          )
          await expect(tx3).to.be.rejectedWith( RevertError("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS") )
        })

        it('should REVERT if arrays are not the same length', async () => {
          let data = getBuyTokenData(userAddress, [0, 1], [tokenAmountToBuy], deadline)
          const tx1 = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, data, TX_PARAM)
          await expect(tx1).to.be.rejectedWith(RevertError())

          data = getBuyTokenData(userAddress, [0], [tokenAmountToBuy, tokenAmountToBuy], deadline)
          const tx2 = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, data, TX_PARAM)
          await expect(tx2).to.be.rejectedWith(RevertError(erc1155_error_prefix + "_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH"))
        })
        
        it('should buy tokens if currency amount is sufficient', async () => {
          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.fulfilled
        })

        describe('When trade is successful', async () => {
          let tx;

          beforeEach(async () => {
            tx = await userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
              {gasLimit: 8000000}
            )
          })

          it('should update Tokens balances if it passes', async () => {
            for (let i = 0; i < types.length; i++) {
              const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
              const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

              expect(exchangeBalance[0]).to.be.eql(tokenAmountToAdd.sub(tokenAmountToBuy))
              expect(userBalance[0]).to.be.eql(BigNumber.from(nTokensPerType).add(tokenAmountToBuy))
            }
          })
      
          it('should update currency balances if it passes', async () => {
              const exchangeBalance = await userCurrencyContract.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
              const userBalance = await userCurrencyContract.functions.balanceOf(userAddress, currencyID)

              expect(exchangeBalance[0]).to.be.eql(currencyAmountToAdd.mul(nTokenTypes).add(cost))
              expect(userBalance[0]).to.be.eql(currencyAmount.sub(cost))
          })

          it('should update the currency per token reserve', async () => {
            const reserves = await niftyswapExchangeContract.functions.getCurrencyReserves(types)
            for (let i = 0; i < types.length; i++) {
              expect(reserves[0][i]).to.be.eql( currencyAmountToAdd.add(cost.div(nTokenTypes)))
            }
          })

          it('should have token sell price adjusted', async () => {
            const price = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([0], [tokenAmountToBuy]))[0];

            let currencyReserve = currencyAmountToAdd.add(cost.div(nTokenTypes))
            let tokenReserve = tokenAmountToAdd.sub(tokenAmountToBuy)

            let numerator = currencyReserve.mul(tokenAmountToBuy).mul(1000)
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
            expect(logs[0].topics[0]).to.be.eql(
              niftyswapExchangeContract.interface.getEventTopic(
                niftyswapExchangeContract.interface.events[
                  "TokensPurchase(address,address,uint256[],uint256[],uint256[])"
                ]
              )
            )
          })
        })

        it('should send to non msg.sender if specified', async () => {
          cost = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([0], [tokenAmountToBuy]))[0][0];
          cost = cost.mul(nTokenTypes)
          buyTokenData = getBuyTokenData(randomWallet.address, types, tokensAmountsToBuy, deadline)

          {gasLimit: 8000000}
          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
          )
          await expect(tx).to.be.fulfilled
          
          // Token bought by sender
          for (let i = 0; i < types.length; i++) {
            const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
            const randomBalance = await userERC1155Contract.functions.balanceOf(randomWallet.address, types[i])
            const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

            expect(exchangeBalance[0]).to.be.eql(tokenAmountToAdd.sub(tokenAmountToBuy))
            expect(randomBalance[0]).to.be.eql(tokenAmountToBuy)
            expect(userBalance[0]).to.be.eql(BigNumber.from(nTokensPerType))
          }

          const exchangeCurrencyBalance = await userCurrencyContract.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
          const randomCurrencyBalance = await userCurrencyContract.functions.balanceOf(randomWallet.address, currencyID)
          const userCurrencyBalance = await userCurrencyContract.functions.balanceOf(userAddress, currencyID)

          expect(exchangeCurrencyBalance[0]).to.be.eql(currencyAmountToAdd.mul(nTokenTypes).add(cost))
          expect(randomCurrencyBalance[0]).to.be.eql(ethers.constants.Zero)
          expect(userCurrencyBalance[0]).to.be.eql(currencyAmount.sub(cost))
        })

        it('should send to msg.sender if 0x0 is specified as recipient', async () => {
          cost = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([0], [tokenAmountToBuy]))[0][0];
          cost = cost.mul(nTokenTypes)
          buyTokenData = getBuyTokenData(ZERO_ADDRESS, types, tokensAmountsToBuy, deadline)

          const tx = userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
            {gasLimit: 8000000}
          )
          await expect(tx).to.be.fulfilled
          
          // Token sold from sender
          for (let i = 0; i < types.length; i++) {
            const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
            const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

            expect(exchangeBalance[0]).to.be.eql(tokenAmountToAdd.sub(tokenAmountToBuy))
            expect(userBalance[0]).to.be.eql(BigNumber.from(nTokensPerType).add(tokenAmountToBuy))
          }

          const exchangeCurrencyBalance = await userCurrencyContract.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
          const userCurrencyBalance = await userCurrencyContract.functions.balanceOf(userAddress, currencyID)

          expect(exchangeCurrencyBalance[0]).to.be.eql(currencyAmountToAdd.mul(nTokenTypes).add(cost))
          expect(userCurrencyBalance[0]).to.be.eql(currencyAmount.sub(cost))
        })
      })

      describe('Edge cases', () => {
  
        it('Pool can not go to zero token in reserve', async () => {
          const minBaseCurrency = BigNumber.from(1000000000)
          const currencyAmountsToAdd: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => minBaseCurrency)
          const tokenAmountsToAdd: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => BigNumber.from(1))
          const addLiquidityData: string = getAddLiquidityData(currencyAmountsToAdd, deadline)
          
          // Add 1000000000:1 for all pools
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 50000000}
          )
    
          // Trying to buy the only tokn will fail as it will cause a division by 0
          let tx = niftyswapExchangeContract.functions.getPrice_currencyToToken([types[0]], [1])
          await expect(tx).to.be.rejected
        })

        it('Pool stuck at 1 token can go back up to normal with loss', async () => {
          const initialBaseCurrency = BigNumber.from(10**9)
          const currencyAmountsToAdd: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => initialBaseCurrency)
          const tokenAmountsToAdd: BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => BigNumber.from(1))
          const addLiquidityData: string = getAddLiquidityData(currencyAmountsToAdd, deadline)
          
          // Add 1000000000:1 for all pools
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
            {gasLimit: 50000000}
          )

          // Correct price should be 10**18 currency per token, not 10**9
          // To correct for this, we will add small amount of liquidity and correct the price
          // then withdraw liquidity.

          // To bring the price to around 10**18, we need to add at least sqrt(10**9)-1 tokens (~31622), ignoring fee
          // to liquidity pool then sell but 1 token. This will will give us a price of ~ 10**18 per 1 token,
          // which is the desired price for users to start selling the assets or add liquidity.

          // Add 31622 tokens to pool
          let maxBaseCurrency_1 = (BigNumber.from(10)).pow(18)
          let currencyAmountsToAdd_1 = new Array(nTokenTypes).fill('').map((a, i) => maxBaseCurrency_1)
          const tokenAmountsToAdd_1 = new Array(nTokenTypes).fill('').map((a, i) => BigNumber.from(31622))
          const addLiquidityData_1 = getAddLiquidityData(currencyAmountsToAdd_1, deadline)          
          await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd_1, addLiquidityData_1,
            {gasLimit: 50000000}
          )

          // Buy 31622 tokens, to leave a ratio of 10**18 : 1, testing with 1 pool
          let amount_to_buy = BigNumber.from(31622)
          let cost = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([types[0]], [amount_to_buy]))[0][0]
          let buyTokenData = getBuyTokenData(userAddress, [types[0]], [amount_to_buy], deadline)
          await userCurrencyContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, currencyID, cost, buyTokenData,
            {gasLimit: 8000000}
          )

          // Pool should have more than 10**18 currency and 1 token
          let expected_price = cost.add(amount_to_buy.add(1).mul((BigNumber.from(10)).pow(9)))
          let currency_reserve = (await niftyswapExchangeContract.functions.getCurrencyReserves([types[0]]))[0]
          let token_reserve = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[0])
          expect(token_reserve[0]).to.be.eql(BigNumber.from(1))
          expect(currency_reserve[0]).to.be.eql(expected_price)
        })
        
      })
    })
  })
})
