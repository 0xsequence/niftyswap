export enum MethodSignature {
  BUYTOKENS = '0xb2d81047',
  SELLTOKENS = '0xdb08ec97',
  ADDLIQUIDITY = '0x82da2b73',
  REMOVELIQUIDITY = '0x5c0bf259'
}

export enum MethodSignature20 {
  BUYTOKENS = '0xb2d81047',
  SELLTOKENS = '0xade79c7a',
  ADDLIQUIDITY = '0x82da2b73',
  REMOVELIQUIDITY = '0x5c0bf259'
}

export const BuyTokensType = `tuple(
  address recipient,
  uint256[] tokensBoughtIDs,
  uint256[] tokensBoughtAmounts,
  uint256 deadline
)`

export const SellTokensType = `tuple(
  address recipient,
  uint256 minBaseTokens,
  uint256 deadline
)`

export const SellTokens20Type = `tuple(
  address recipient,
  uint256 minCurrency,
  address[] extraFeeRecipients,
  uint256[] extraFeeAmounts,
  uint256 deadline
)`

export const AddLiquidityType = `tuple(
  uint256[] maxCurrency,
  uint256 deadline
)`

export const RemoveLiquidityType = `tuple(
  uint256[] minCurrency,
  uint256[] minTokens,
  uint256 deadline
)`
