import * as ethers from 'ethers'

import { AbstractContract, expect, BigNumber, getBuyTokenData, getSellTokenData, getAddLiquidityData } from './utils'

import * as utils from './utils'

import { ERC1155Mock, ERC1155PackedBalanceMock, NiftyswapExchange, NiftyswapFactory } from 'src/gen/typechain'

import { abi as exchangeABI } from '@0xsequence/niftyswap/artifacts/contracts/exchange/NiftyswapExchange.sol/NiftyswapExchange.json'
import { web3 } from 'hardhat'

// init test wallets from package.json mnemonic

const { wallet: ownerWallet, provider: ownerProvider, signer: ownerSigner } = utils.createTestWallet(web3, 0) // eslint-disable-line @typescript-eslint/no-unused-vars
const { wallet: userWallet, provider: userProvider, signer: userSigner } = utils.createTestWallet(web3, 2) // eslint-disable-line @typescript-eslint/no-unused-vars
const { wallet: operatorWallet, provider: operatorProvider, signer: operatorSigner } = utils.createTestWallet(web3, 4) // eslint-disable-line @typescript-eslint/no-unused-vars

const getBig = (id: number) => BigNumber.from(id)

describe('NiftyswapExchange', () => {
  let userAddress: string
  let operatorAddress: string
  let erc1155Abstract: AbstractContract
  let erc1155PackedAbstract: AbstractContract
  let niftyswapFactoryAbstract: AbstractContract

  // ERC-1155 token
  let ownerERC1155Contract: ERC1155PackedBalanceMock
  let userERC1155Contract: ERC1155PackedBalanceMock
  let operatorERC1155Contract: ERC1155PackedBalanceMock

  // Currency
  let ownerCurrencyContract: ERC1155Mock
  let userCurrencyContract: ERC1155Mock
  let operatorCurrencyContract: ERC1155Mock

  let niftyswapFactoryContract: NiftyswapFactory
  let niftyswapExchangeContract: NiftyswapExchange

  // Token Param
  const nTokenTypes = 400 //560
  const nTokensPerType = 500000

  // Currency Param
  const currencyID = 2
  const currencyAmount = BigNumber.from(10000000).mul(BigNumber.from(10).pow(18))

  const types = new Array(nTokenTypes).fill('').map((a, i) => getBig(i))
  const values = new Array(nTokenTypes).fill('').map(() => nTokensPerType)

  // load contract abi and deploy to test server
  beforeEach(async () => {
    userAddress = await userWallet.getAddress()
    operatorAddress = await operatorWallet.getAddress()
    erc1155Abstract = await AbstractContract.fromArtifactName('ERC1155Mock')
    erc1155PackedAbstract = await AbstractContract.fromArtifactName('ERC1155PackedBalanceMock')
    niftyswapFactoryAbstract = await AbstractContract.fromArtifactName('NiftyswapFactory')
  })

  // deploy before each test, to reset state of contract
  beforeEach(async () => {
    // Deploy currency contract
    ownerCurrencyContract = (await erc1155Abstract.deploy(ownerWallet)) as ERC1155Mock
    userCurrencyContract = (await ownerCurrencyContract.connect(userSigner)) as ERC1155Mock
    operatorCurrencyContract = (await ownerCurrencyContract.connect(operatorSigner)) as ERC1155Mock

    // Deploy ERC-1155
    ownerERC1155Contract = (await erc1155PackedAbstract.deploy(ownerWallet)) as ERC1155PackedBalanceMock
    operatorERC1155Contract = (await ownerERC1155Contract.connect(operatorSigner)) as ERC1155PackedBalanceMock
    userERC1155Contract = (await ownerERC1155Contract.connect(userSigner)) as ERC1155PackedBalanceMock

    // Deploy Niftyswap factory
    niftyswapFactoryContract = (await niftyswapFactoryAbstract.deploy(ownerWallet)) as NiftyswapFactory

    // Create exchange contract for the ERC-1155 token
    await niftyswapFactoryContract.functions.createExchange(
      ownerERC1155Contract.address,
      ownerCurrencyContract.address,
      currencyID
    )
    const exchangeAddress = (
      await niftyswapFactoryContract.functions.tokensToExchange(
        ownerERC1155Contract.address,
        ownerCurrencyContract.address,
        currencyID
      )
    )[0]

    // Type exchange contract
    niftyswapExchangeContract = new ethers.Contract(exchangeAddress, exchangeABI, ownerProvider) as NiftyswapExchange

    // Mint Token to owner and user
    await ownerERC1155Contract.functions.batchMintMock(operatorAddress, types, values, [])
    await ownerERC1155Contract.functions.batchMintMock(userAddress, types, values, [])

    // Mint currency to owner and user
    await ownerCurrencyContract.functions.mintMock(operatorAddress, currencyID, currencyAmount, [])
    await ownerCurrencyContract.functions.mintMock(userAddress, currencyID, currencyAmount, [])

    // Authorize Niftyswap to transfer funds on your behalf for addLiquidity & transfers
    await operatorCurrencyContract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
    await operatorERC1155Contract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
    await userCurrencyContract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
    await userERC1155Contract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
  })

  describe('_tokenToCurrency() function', () => {
    //Liquidity
    const tokenAmountToAdd = BigNumber.from(10)
    const currencyAmountToAdd = BigNumber.from(10).pow(18)
    const currencyAmountsToAdd: ethers.BigNumber[] = []
    const tokenAmountsToAdd: ethers.BigNumber[] = []

    //Sell
    const tokenAmountToSell = BigNumber.from(50)
    const tokensAmountsToSell: ethers.BigNumber[] = []
    let sellTokenData: string

    for (let i = 0; i < nTokenTypes; i++) {
      currencyAmountsToAdd.push(currencyAmountToAdd)
      tokenAmountsToAdd.push(tokenAmountToAdd)
      tokensAmountsToSell.push(tokenAmountToSell)
    }
    const addLiquidityData = getAddLiquidityData(currencyAmountsToAdd, 10000000)

    beforeEach(async () => {
      // Add liquidity
      await operatorERC1155Contract.functions.safeBatchTransferFrom(
        operatorAddress,
        niftyswapExchangeContract.address,
        types,
        tokenAmountsToAdd,
        addLiquidityData,
        { gasLimit: 30000000 }
      )

      // Sell
      const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0]
      sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokenTypes), 10000000)
    })

    it('sell 1 tokens should pass', async () => {
      const nTokens = 1
      const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0]

      sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokens), 10000000)

      const tokensSoldIDs = new Array(nTokens).fill('').map((a, i) => getBig(i))
      const tokensSoldAmounts = new Array(nTokens).fill('').map(() => tokenAmountToSell)

      const tx = userERC1155Contract.functions.safeBatchTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        tokensSoldIDs,
        tokensSoldAmounts,
        sellTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('sell 5 tokens should pass', async () => {
      const nTokens = 5
      const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0]
      sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokens), 10000000)

      const tokensSoldIDs = new Array(nTokens).fill('').map((_a, i) => getBig(i))
      const tokensSoldAmounts = new Array(nTokens).fill('').map(() => tokenAmountToSell)

      const tx = userERC1155Contract.functions.safeBatchTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        tokensSoldIDs,
        tokensSoldAmounts,
        sellTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('sell 30 tokens should pass', async () => {
      const nTokens = 30

      const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0]
      sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokens), 10000000)

      const tokensSoldIDs = new Array(nTokens).fill('').map((_a, i) => getBig(i))
      const tokensSoldAmounts = new Array(nTokens).fill('').map(() => tokenAmountToSell)

      const tx = userERC1155Contract.functions.safeBatchTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        tokensSoldIDs,
        tokensSoldAmounts,
        sellTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('sell 80 tokens should pass', async () => {
      const nTokens = 80

      const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0]
      sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokens), 10000000)

      const tokensSoldIDs = new Array(nTokens).fill('').map((_a, i) => getBig(i))
      const tokensSoldAmounts = new Array(nTokens).fill('').map(() => tokenAmountToSell)

      const tx = userERC1155Contract.functions.safeBatchTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        tokensSoldIDs,
        tokensSoldAmounts,
        sellTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('sell 400 tokens should pass', async () => {
      const nTokens = 400

      const price = (await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]))[0]
      sellTokenData = getSellTokenData(userAddress, price[0].mul(nTokens), 10000000)

      const tokensSoldIDs = new Array(nTokens).fill('').map((_a, i) => getBig(i))
      const tokensSoldAmounts = new Array(nTokens).fill('').map(() => tokenAmountToSell)

      const tx = userERC1155Contract.functions.safeBatchTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        tokensSoldIDs,
        tokensSoldAmounts,
        sellTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })
  })

  describe('_currencyToToken() function', () => {
    //Liquidity
    const tokenAmountToAdd = BigNumber.from(500)
    const currencyAmountToAdd = BigNumber.from(10).pow(18).mul(500)
    const currencyAmountsToAdd: ethers.BigNumber[] = []
    const tokenAmountsToAdd: ethers.BigNumber[] = []

    //Buy
    const tokenAmountToBuy = BigNumber.from(50)
    const tokensAmountsToBuy: ethers.BigNumber[] = []
    let buyTokenData: string
    let cost: ethers.BigNumber

    for (let i = 0; i < nTokenTypes; i++) {
      currencyAmountsToAdd.push(currencyAmountToAdd)
      tokenAmountsToAdd.push(tokenAmountToAdd)
      tokensAmountsToBuy.push(tokenAmountToBuy)
    }
    const addLiquidityData = getAddLiquidityData(currencyAmountsToAdd, 10000000)

    beforeEach(async () => {
      // Add liquidity
      await operatorERC1155Contract.functions.safeBatchTransferFrom(
        operatorAddress,
        niftyswapExchangeContract.address,
        types,
        tokenAmountsToAdd,
        addLiquidityData,
        { gasLimit: 30000000 }
      )

      // Sell
      cost = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([0], [tokenAmountToBuy]))[0][0]
      cost = cost.mul(nTokenTypes)
      buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuy, 10000000)
    })

    it('buy 1 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(1)
      buyTokenData = getBuyTokenData(userAddress, [1], [BigNumber.from(1)], 10000000)

      const tx = userCurrencyContract.functions.safeTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        currencyID,
        cost,
        buyTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('buy 5 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(5)

      buyTokenData = getBuyTokenData(
        userAddress,
        new Array(5).fill('').map((_a, i) => getBig(i)),
        new Array(5).fill('').map(() => getBig(1)),
        10000000
      )

      const tx = userCurrencyContract.functions.safeTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        currencyID,
        cost,
        buyTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('buy 30 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(30)
      buyTokenData = getBuyTokenData(
        userAddress,
        new Array(30).fill('').map((_a, i) => getBig(i)),
        new Array(30).fill('').map(() => getBig(1)),
        10000000
      )

      const tx = userCurrencyContract.functions.safeTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        currencyID,
        cost,
        buyTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('buy 80 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(80)
      buyTokenData = getBuyTokenData(
        userAddress,
        new Array(80).fill('').map((_a, i) => getBig(i)),
        new Array(80).fill('').map(() => getBig(1)),
        10000000
      )

      const tx = userCurrencyContract.functions.safeTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        currencyID,
        cost,
        buyTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })

    it('buy 400 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(400)
      buyTokenData = getBuyTokenData(
        userAddress,
        new Array(400).fill('').map((_a, i) => getBig(i)),
        new Array(400).fill('').map(() => getBig(1)),
        10000000
      )

      const tx = userCurrencyContract.functions.safeTransferFrom(
        userAddress,
        niftyswapExchangeContract.address,
        currencyID,
        cost,
        buyTokenData,
        { gasLimit: 8000000 }
      )
      await expect(tx).to.be.fulfilled
    })
  })
})
