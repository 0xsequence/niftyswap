import * as ethers from 'ethers'

import { 
  AbstractContract, 
  expect, 
  BigNumber, 
  RevertError,
  BuyTokensType,
  SellTokensType,
  AddLiquidityType, 
  RemoveLiquidityType,
  methodsSignature
} from './utils'

import { 
  BuyTokensObj, 
  SellTokensObj, 
  AddLiquidityObj, 
  RemoveLiquidityObj 
} from 'typings/txTypes';

import * as utils from './utils'

import { ERC1155Mock } from 'typings/contracts/ERC1155Mock'
import { ERC1155PackedBalanceMock } from 'typings/contracts/ERC1155PackedBalanceMock'
import { NiftyswapExchange } from 'typings/contracts/NiftyswapExchange'
import { NiftyswapFactory } from 'typings/contracts/NiftyswapFactory'
//@ts-ignore
import { abi as exchangeABI } from './contracts/NiftyswapExchange.json'

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

  // Token Param
  let types: any[] = [], values: any[] = []
  const nTokenTypes    = 400 //560
  const nTokensPerType = 500000

  // Base Token Param
  const baseTokenID = 666;
  const baseTokenAmount = new BigNumber(10000000).mul(new BigNumber(10).pow(18))

  // load contract abi and deploy to test server
  before(async () => {
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
    niftyswapFactoryContract = await niftyswapFactoryAbstract.deploy(ownerWallet, [
      ownerBaseTokenContract.address,
      baseTokenID
    ]) as NiftyswapFactory

    // Create exchange contract for the ERC-1155 token
    await niftyswapFactoryContract.functions.createExchange(ownerERC1155Contract.address)
    const exchangeAddress = await niftyswapFactoryContract.functions.getExchange(ownerERC1155Contract.address)
    
    // Type exchange contract
    niftyswapExchangeContract = new ethers.Contract(exchangeAddress, exchangeABI, ownerProvider) as NiftyswapExchange
  
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

  describe('_tokenToBase() function', () => {

    //Liquidity
    let tokenAmountToAdd = new BigNumber(10);
    let baseAmountToAdd = new BigNumber(10).pow(18)
    let baseAmountsToAdd: ethers.utils.BigNumber[] = []
    let tokenAmountsToAdd: ethers.utils.BigNumber[] = []
    let addLiquidityData: string;

    //Sell
    let tokenAmountToSell = new BigNumber(50)
    let tokensAmountsToSell: ethers.utils.BigNumber[] = []
    let sellTokenData: string;

    before(async () => {
      for (let i = 0; i < nTokenTypes; i++) {
        baseAmountsToAdd.push(baseAmountToAdd)
        tokenAmountsToAdd.push(tokenAmountToAdd)
        tokensAmountsToSell.push(tokenAmountToSell)
      }

      // Liquidity
      const addLiquidityObj = {
        maxBaseTokens: baseAmountsToAdd,
        deadline: 10000000
      } as AddLiquidityObj

      addLiquidityData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', AddLiquidityType], [methodsSignature.ADDLIQUIDITY, addLiquidityObj])
    
    })

    beforeEach(async () => {
      // Add liquidity
      await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
        {gasLimit: 30000000}
      )
      
      // Sell
      const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
      const sellTokenObj = {
        minBaseTokens: price[0].mul(nTokenTypes),
        deadline: 10000000
      } as SellTokensObj

      sellTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', SellTokensType], [methodsSignature.SELLTOKENS, sellTokenObj])
    })

    it('sell 1 tokens should pass', async () => {
      const nTokens = 1
      
      const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
      const sellTokenObj = {
        minBaseTokens: price[0].mul(nTokens),
        deadline: 10000000
      } as SellTokensObj


      sellTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', SellTokensType], [methodsSignature.SELLTOKENS, sellTokenObj])

      let tokensSoldIDs = new Array(nTokens).fill('').map((a, i) => getBig(i))
      let tokensSoldAmounts = new Array(nTokens).fill('').map((a, i) => tokenAmountToSell)
      
      const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, tokensSoldIDs, tokensSoldAmounts, sellTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

    it('sell 5 tokens should pass', async () => {
      const nTokens = 5
      
      const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
      const sellTokenObj = {
        minBaseTokens: price[0].mul(nTokens),
        deadline: 10000000
      } as SellTokensObj


      sellTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', SellTokensType], [methodsSignature.SELLTOKENS, sellTokenObj])

      let tokensSoldIDs = new Array(nTokens).fill('').map((a, i) => getBig(i))
      let tokensSoldAmounts = new Array(nTokens).fill('').map((a, i) => tokenAmountToSell)
      
      const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, tokensSoldIDs, tokensSoldAmounts, sellTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

    it('sell 30 tokens should pass', async () => {
      const nTokens = 30
      
      const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
      const sellTokenObj = {
        minBaseTokens: price[0].mul(nTokens),
        deadline: 10000000
      } as SellTokensObj


      sellTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', SellTokensType], [methodsSignature.SELLTOKENS, sellTokenObj])

      let tokensSoldIDs = new Array(nTokens).fill('').map((a, i) => getBig(i))
      let tokensSoldAmounts = new Array(nTokens).fill('').map((a, i) => tokenAmountToSell)
      
      const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, tokensSoldIDs, tokensSoldAmounts, sellTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })


    it('sell 80 tokens should pass', async () => {
      const nTokens = 80
      
      const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
      const sellTokenObj = {
        minBaseTokens: price[0].mul(nTokens),
        deadline: 10000000
      } as SellTokensObj


      sellTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', SellTokensType], [methodsSignature.SELLTOKENS, sellTokenObj])

      let tokensSoldIDs = new Array(nTokens).fill('').map((a, i) => getBig(i))
      let tokensSoldAmounts = new Array(nTokens).fill('').map((a, i) => tokenAmountToSell)
      
      const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, tokensSoldIDs, tokensSoldAmounts, sellTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

    it('sell 400 tokens should pass', async () => {
      const nTokens = 400
      
      const price = await niftyswapExchangeContract.functions.getPrice_tokenToBase([0], [tokenAmountToSell]);
      const sellTokenObj = {
        minBaseTokens: price[0].mul(nTokens),
        deadline: 10000000
      } as SellTokensObj


      sellTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', SellTokensType], [methodsSignature.SELLTOKENS, sellTokenObj])

      let tokensSoldIDs = new Array(nTokens).fill('').map((a, i) => getBig(i))
      let tokensSoldAmounts = new Array(nTokens).fill('').map((a, i) => tokenAmountToSell)
      
      const tx = userERC1155Contract.functions.safeBatchTransferFrom(userAddress, niftyswapExchangeContract.address, tokensSoldIDs, tokensSoldAmounts, sellTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

  })

  describe('_baseToToken() function', () => {

    //Liquidity
    let tokenAmountToAdd = new BigNumber(500);
    let baseAmountToAdd = new BigNumber(10).pow(18).mul(500)
    let baseAmountsToAdd: ethers.utils.BigNumber[] = []
    let tokenAmountsToAdd: ethers.utils.BigNumber[] = []
    let addLiquidityData: string;

    //Buy
    let tokenAmountToBuy = new BigNumber(50)
    let tokensAmountsToBuy: ethers.utils.BigNumber[] = []
    let buyTokenData: string;
    let cost: ethers.utils.BigNumber

    before(async () => {
      for (let i = 0; i < nTokenTypes; i++) {
        baseAmountsToAdd.push(baseAmountToAdd)
        tokenAmountsToAdd.push(tokenAmountToAdd)
        tokensAmountsToBuy.push(tokenAmountToBuy)
      }

      // Liquidity
      const addLiquidityObj = {
        maxBaseTokens: baseAmountsToAdd,
        deadline: 10000000
      } as AddLiquidityObj

      addLiquidityData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', AddLiquidityType], [methodsSignature.ADDLIQUIDITY, addLiquidityObj])
    
    })

    beforeEach(async () => {
      // Add liquidity
      await operatorERC1155Contract.functions.safeBatchTransferFrom(operatorAddress, niftyswapExchangeContract.address, types, tokenAmountsToAdd, addLiquidityData,
        {gasLimit: 30000000}
      )

      // Sell
      cost = (await niftyswapExchangeContract.functions.getPrice_baseToToken([0], [tokenAmountToBuy]))[0];
      cost = cost.mul(nTokenTypes)
      const buyTokenObj = {
        tokensBoughtIDs: types,
        tokensBoughtAmounts: tokensAmountsToBuy,
        deadline: 10000000
      } as BuyTokensObj


      buyTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', BuyTokensType], [methodsSignature.BUYTOKENS, buyTokenObj])
    })

    it('buy 1 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(1)
      const buyTokenObj = {
        tokensBoughtIDs: [1],
        tokensBoughtAmounts: [1],
        deadline: 10000000
      } as BuyTokensObj


      buyTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', BuyTokensType], [methodsSignature.BUYTOKENS, buyTokenObj])
      
      const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

    it('buy 5 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(5)
      const buyTokenObj = {
        tokensBoughtIDs: new Array(5).fill('').map((a, i) => getBig(i)),
        tokensBoughtAmounts: new Array(5).fill('').map((a, i) => getBig(1)),
        deadline: 10000000
      } as BuyTokensObj


      buyTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', BuyTokensType], [methodsSignature.BUYTOKENS, buyTokenObj])

      const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

    it('buy 30 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(30)
      const buyTokenObj = {
        tokensBoughtIDs: new Array(30).fill('').map((a, i) => getBig(i)),
        tokensBoughtAmounts: new Array(30).fill('').map((a, i) => getBig(1)),
        deadline: 10000000
      } as BuyTokensObj


      buyTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', BuyTokensType], [methodsSignature.BUYTOKENS, buyTokenObj])

      const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })


    it('buy 80 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(80)
      const buyTokenObj = {
        tokensBoughtIDs: new Array(80).fill('').map((a, i) => getBig(i)),
        tokensBoughtAmounts: new Array(80).fill('').map((a, i) => getBig(1)),
        deadline: 10000000
      } as BuyTokensObj


      buyTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', BuyTokensType], [methodsSignature.BUYTOKENS, buyTokenObj])

      const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

    it('buy 400 tokens should pass', async () => {
      cost = cost.div(nTokenTypes).mul(400)
      const buyTokenObj = {
        tokensBoughtIDs: new Array(400).fill('').map((a, i) => getBig(i)),
        tokensBoughtAmounts: new Array(400).fill('').map((a, i) => getBig(1)),
        deadline: 10000000
      } as BuyTokensObj


      buyTokenData = ethers.utils.defaultAbiCoder.encode(
        ['bytes4', BuyTokensType], [methodsSignature.BUYTOKENS, buyTokenObj])

      const tx = userBaseTokenContract.functions.safeTransferFrom(userAddress, niftyswapExchangeContract.address, baseTokenID, cost, buyTokenData,
        {gasLimit: 8000000}
      )
      await expect(tx).to.be.fulfilled
    })

  })


})
