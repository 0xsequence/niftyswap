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

import { ERC1155Mock } from '../typings/contracts/ERC1155Mock'
import { ERC20Mock } from 'erc20-meta-token/typings/contracts/ERC20Mock'
import { NiftyswapExchange } from '../typings/contracts/NiftyswapExchange'
import { NiftyswapFactory } from '../typings/contracts/NiftyswapFactory'
import { MetaERC20Wrapper } from 'erc20-meta-token/typings/contracts/MetaERC20Wrapper'
import { WrapAndNiftyswap } from '../typings/contracts/WrapAndNiftyswap'

import { abi as exchangeABI } from '../artifacts/NiftyswapExchange.json'
import { Zero } from 'ethers/constants'
import { BigNumber } from 'ethers/utils'
import { web3 } from '@nomiclabs/buidler'

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

const getBig = (id: number) => new BigNumber(id);

describe('WrapAndSwap', () => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  let ownerAddress: string
  let userAddress: string
  let operatorAddress: string
  let erc1155Abstract: AbstractContract
  let niftyswapFactoryAbstract: AbstractContract
  let erc20Abstract: AbstractContract
  let tokenWrapperAbstract: AbstractContract
  let wrapAndNiftyswapAbstract: AbstractContract

  // ERC-1155 token
  let ownerERC1155Contract: ERC1155Mock
  let userERC1155Contract: ERC1155Mock
  let operatorERC1155Contract: ERC1155Mock

  // ERC-1155 token
  let ownerERC20Contract: ERC20Mock
  let userERC20Contract: ERC20Mock
  let operatorERC20Contract: ERC20Mock

  // Wrapper contract
  let ownerTokenWrapper: MetaERC20Wrapper 
  let userTokenWrapper: MetaERC20Wrapper 
  let operatorTokenWrapper: MetaERC20Wrapper 
  
  // Wrap and Swap contract
  let ownerWrapAndNiftyswap: WrapAndNiftyswap
  let userWrapAndNiftyswap: WrapAndNiftyswap

  // Niftyswap exchange
  let niftyswapFactoryContract: NiftyswapFactory
  let niftyswapExchangeContract: NiftyswapExchange

  // Contract addresses
  let erc20: string
  let erc1155: string
  let exchange: string
  let wrapAndSwap: string

  // Token Param
  const nTokenTypes    = 30 //560
  const nTokensPerType = 500000

  // Currency Param
  const currencyAmount = new BigNumber(10000000).mul(new BigNumber(10).pow(18))
  const currencyID = 2

  // Add liquidity data
  const tokenAmountToAdd = new BigNumber(300);
  const currencyAmountToAdd = (new BigNumber(10).pow(18)).mul(299)

  // Transactions parameters
  const TX_PARAM = {gasLimit: 5000000}

  const deadline = Math.floor(Date.now() / 1000) + 100000
  
  // Arrays
  const types = new Array(nTokenTypes).fill('').map((a, i) => getBig(i))
  const values = new Array(nTokenTypes).fill('').map((a, i) => nTokensPerType)
  const currencyAmountsToAdd: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => currencyAmountToAdd)
  const tokenAmountsToAdd: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToAdd)
  const addLiquidityData: string = getAddLiquidityData(currencyAmountsToAdd, deadline)

  // load contract abi and deploy to test server
  before(async () => {
    ownerAddress = await ownerWallet.getAddress()
    userAddress = await userWallet.getAddress()
    operatorAddress = await operatorWallet.getAddress()
    erc1155Abstract = await AbstractContract.fromArtifactName('ERC1155Mock')
    niftyswapFactoryAbstract = await AbstractContract.fromArtifactName('NiftyswapFactory')
    erc20Abstract = await AbstractContract.fromArtifactName('ERC20TokenMock')
    tokenWrapperAbstract = await AbstractContract.fromArtifactName('MetaERC20WrapperMock')
    wrapAndNiftyswapAbstract = await AbstractContract.fromArtifactName('WrapAndNiftyswap')
  })

  // deploy before each test, to reset state of contract
  beforeEach(async () => {
  // Deploy ERC-1155
    ownerERC1155Contract = await erc1155Abstract.deploy(ownerWallet) as ERC1155Mock
    operatorERC1155Contract = await ownerERC1155Contract.connect(operatorSigner) as ERC1155Mock
    userERC1155Contract = await ownerERC1155Contract.connect(userSigner) as ERC1155Mock

    // Deploy Currency Token contract
    ownerERC20Contract = await erc20Abstract.deploy(ownerWallet) as ERC20Mock
    userERC20Contract = await ownerERC20Contract.connect(userSigner) as ERC20Mock
    operatorERC20Contract = await ownerERC20Contract.connect(operatorSigner) as ERC20Mock

    // Deploy token wrapper contract
    ownerTokenWrapper = await tokenWrapperAbstract.deploy(ownerWallet) as MetaERC20Wrapper
    userTokenWrapper = await ownerTokenWrapper.connect(userSigner) as MetaERC20Wrapper
    operatorTokenWrapper = await ownerTokenWrapper.connect(operatorSigner) as MetaERC20Wrapper

    // Deploy Niftyswap factory
    niftyswapFactoryContract = await niftyswapFactoryAbstract.deploy(ownerWallet) as NiftyswapFactory

    // Create exchange contract for the ERC-1155 token
    await niftyswapFactoryContract.functions.createExchange(
      ownerERC1155Contract.address, 
      ownerTokenWrapper.address, 
      currencyID
    )
    
    // Retrieve exchange address
    const exchangeAddress = await niftyswapFactoryContract.functions.tokensToExchange(ownerERC1155Contract.address, ownerTokenWrapper.address, currencyID)
    
    // Type exchange contract
    niftyswapExchangeContract = await new ethers.Contract(exchangeAddress, exchangeABI, ownerProvider) as NiftyswapExchange

    //Register addresses
    erc20 = ownerERC20Contract.address
    erc1155 = ownerERC1155Contract.address
    exchange = exchangeAddress
    
    // Register ERC-20 in tokenWrapper
    await ownerERC20Contract.functions.mockMint(ownerAddress, 1)
    await ownerERC20Contract.functions.approve(ownerTokenWrapper.address, 1)
    await ownerTokenWrapper.functions.deposit(erc20, ownerAddress, 1)
    
    // Deploy WrapAndNiftyswap
    ownerWrapAndNiftyswap = await wrapAndNiftyswapAbstract.deploy(ownerWallet, [
      ownerTokenWrapper.address,
      exchange,
      erc20,
      erc1155
    ]) as WrapAndNiftyswap
    userWrapAndNiftyswap = await ownerWrapAndNiftyswap.connect(userSigner) as WrapAndNiftyswap
    wrapAndSwap = ownerWrapAndNiftyswap.address

    // Mint Token to owner and user
    await ownerERC1155Contract.functions.batchMintMock(operatorAddress, types, values, [])
    await ownerERC1155Contract.functions.batchMintMock(userAddress, types, values, [])

    // Mint Currency token to owner and user
    await ownerERC20Contract.functions.mockMint(operatorAddress, currencyAmountToAdd.mul(nTokenTypes))
    await ownerERC20Contract.functions.mockMint(userAddress, currencyAmount)

    // Wrap some tokens for niftyswap liquidity
    await operatorERC20Contract.functions.approve(ownerTokenWrapper.address, new BigNumber(2).pow(256).sub(1))
    await operatorTokenWrapper.functions.deposit(operatorERC20Contract.address, operatorAddress, currencyAmountToAdd.mul(nTokenTypes))

    // Authorize Niftyswap to transfer funds on your behalf for addLiquidity & transfers
    await operatorTokenWrapper.functions.setApprovalForAll(niftyswapExchangeContract.address, true)
    await operatorERC1155Contract.functions.setApprovalForAll(niftyswapExchangeContract.address, true)

    // Deposit initial liquidity
    await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, exchangeAddress, types, tokenAmountsToAdd, addLiquidityData,
      TX_PARAM
    )
  
    // User approves wrapAndSwap
    await userERC20Contract.functions.approve(userWrapAndNiftyswap.address, new BigNumber(2).pow(256).sub(1), TX_PARAM)
  })

  describe('wrapAndSwap() function', () => {
    const tokenAmountToBuy = new BigNumber(50)
    const tokensAmountsToBuy: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToBuy)
    let buyTokenData: string;
    let cost: ethers.utils.BigNumber

    beforeEach( async () => {
      cost = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([0], [tokenAmountToBuy]))[0];
      cost = cost.mul(nTokenTypes)
      buyTokenData = getBuyTokenData(ZERO_ADDRESS, types, tokensAmountsToBuy, deadline)
    })

    it('should revert if order recipient is not swapAndWrap contract', async () => {
      let bad_buyTokenData = getBuyTokenData(userAddress, types, tokensAmountsToBuy, deadline)
      const tx = userWrapAndNiftyswap.functions.wrapAndSwap(cost, userAddress, bad_buyTokenData, {gasLimit: 10000000})
      await expect(tx).to.be.rejectedWith(RevertError("WrapAndNiftyswap#wrapAndSwap: ORDER RECIPIENT MUST BE THIS CONTRACT"))
    })

    it('should buy tokens when balances are sufficient', async () => {
      const tx = userWrapAndNiftyswap.functions.wrapAndSwap(cost, userAddress, buyTokenData, {gasLimit: 10000000})
      await expect(tx).to.be.fulfilled
    })

    it('should buy the 2nd time as well', async () => {
      await userWrapAndNiftyswap.functions.wrapAndSwap(cost, userAddress, buyTokenData, {gasLimit: 10000000})
      let cost2 = (await niftyswapExchangeContract.functions.getPrice_currencyToToken([0], [tokenAmountToBuy]))[0];
      cost2 = cost.mul(nTokenTypes)
      let buyTokenData2 = getBuyTokenData(ZERO_ADDRESS, types, tokensAmountsToBuy, deadline)
      let tx = userWrapAndNiftyswap.functions.wrapAndSwap(cost2, userAddress, buyTokenData2, {gasLimit: 10000000})
      await expect(tx).to.be.fulfilled
    })

    context('When wrapAndSwap is completed', () => {
      beforeEach( async () => {
        await userWrapAndNiftyswap.functions.wrapAndSwap(cost, userAddress, buyTokenData, {gasLimit: 10000000})
      })

      it('should update Tokens balances if it passes', async () => {
        for (let i = 0; i < types.length; i++) {
          const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
          const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

          expect(exchangeBalance).to.be.eql(tokenAmountToAdd.sub(tokenAmountToBuy))
          expect(userBalance).to.be.eql(new BigNumber(nTokensPerType).add(tokenAmountToBuy))
        }
      })
  
      it('should update currency balances if it passes', async () => {
          const exchangeBalance = await userTokenWrapper.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
          const userBalance = await userERC20Contract.functions.balanceOf(userAddress)

          expect(exchangeBalance).to.be.eql(currencyAmountToAdd.mul(nTokenTypes).add(cost))
          expect(userBalance).to.be.eql(currencyAmount.sub(cost))
      })

      it('should leave swapAndWrap contract with 0 funds', async () => {
        const erc20Balance = await userERC20Contract.functions.balanceOf(userWrapAndNiftyswap.address)
        const wrappedTokenBalance = await userTokenWrapper.functions.balanceOf(userWrapAndNiftyswap.address, currencyID)
        
        let addresses = new Array(nTokenTypes).fill('').map((a, i) => userWrapAndNiftyswap.address)
        const erc1155Balances = await userERC1155Contract.functions.balanceOfBatch(addresses, types)

        expect(erc20Balance).to.be.eql(Zero)
        expect(wrappedTokenBalance).to.be.eql(Zero)
        for (let i = 0; i < types.length; i++) {
          expect(erc1155Balances[i]).to.be.eql(Zero)
        }
      })

    })
  })

  describe('swapAndUnwrap() function', () => {
    const tokenAmountToSell = new BigNumber(50)
    const tokensAmountsToSell: ethers.utils.BigNumber[] = new Array(nTokenTypes).fill('').map((a, i) => tokenAmountToSell)
    let sellTokenData: string;
    let expectedAmount;

    beforeEach( async () => {
        // Sell
        const price = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]);
        expectedAmount = price[0].mul(nTokenTypes)
        sellTokenData = getSellTokenData(ZERO_ADDRESS, expectedAmount, deadline)
    })

    it('should revert if order recipient is not swapAndWrap contract', async () => {
      let bad_sellTokenData = getSellTokenData(userAddress, expectedAmount, deadline)
      const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, wrapAndSwap, types, tokensAmountsToSell, bad_sellTokenData, {gasLimit: 10000000})
      await expect(tx).to.be.rejectedWith(RevertError("WrapAndNiftyswap#onERC1155BatchReceived: ORDER RECIPIENT MUST BE THIS CONTRACT"))
    })

    it('should sell tokens when balances are sufficient', async () => {
      const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, wrapAndSwap, types, tokensAmountsToSell, sellTokenData, TX_PARAM)
      await expect(tx).to.be.fulfilled
    })

    it('should sell the 2nd time as well', async () => {
      await userERC1155Contract.functions.safeBatchTransferFrom(userAddress, wrapAndSwap, types, tokensAmountsToSell, sellTokenData, TX_PARAM)
      let price2 = await niftyswapExchangeContract.functions.getPrice_tokenToCurrency([0], [tokenAmountToSell]);
      let expectedAmount2 = price2[0].mul(nTokenTypes)
      let sellTokenData2 = getSellTokenData(ZERO_ADDRESS, expectedAmount2, deadline)
      let tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, wrapAndSwap, types, tokensAmountsToSell, sellTokenData2, TX_PARAM)
      await expect(tx).to.be.fulfilled
    })

    context('When wrapAndSwap is completed', () => {
      beforeEach( async () => {
        await userERC1155Contract.functions.safeBatchTransferFrom(userAddress, wrapAndSwap, types, tokensAmountsToSell, sellTokenData, TX_PARAM)
      })

      it('should update Tokens balances if it passes', async () => {
        for (let i = 0; i < types.length; i++) {
          const exchangeBalance = await userERC1155Contract.functions.balanceOf(niftyswapExchangeContract.address, types[i])
          const userBalance = await userERC1155Contract.functions.balanceOf(userAddress, types[i])

          expect(exchangeBalance).to.be.eql(tokenAmountToAdd.add(tokenAmountToSell))
          expect(userBalance).to.be.eql(new BigNumber(nTokensPerType).sub(tokenAmountToSell))
        }
      })
  
      it('should update currency balances if it passes', async () => {
          const exchangeBalance = await userTokenWrapper.functions.balanceOf(niftyswapExchangeContract.address, currencyID)
          const userBalance = await userERC20Contract.functions.balanceOf(userAddress)

          expect(exchangeBalance).to.be.eql(currencyAmountToAdd.mul(nTokenTypes).sub(expectedAmount))
          expect(userBalance).to.be.eql(currencyAmount.add(expectedAmount))
      })

      it('should leave swapAndWrap contract with 0 funds', async () => {
        const erc20Balance = await userERC20Contract.functions.balanceOf(userWrapAndNiftyswap.address)
        const wrappedTokenBalance = await userTokenWrapper.functions.balanceOf(userWrapAndNiftyswap.address, currencyID)
        
        let addresses = new Array(nTokenTypes).fill('').map((a, i) => userWrapAndNiftyswap.address)
        const erc1155Balances = await userERC1155Contract.functions.balanceOfBatch(addresses, types)

        expect(erc20Balance).to.be.eql(Zero)
        expect(wrappedTokenBalance).to.be.eql(Zero)
        for (let i = 0; i < types.length; i++) {
          expect(erc1155Balances[i]).to.be.eql(Zero)
        }
      })

    })
  })
})
