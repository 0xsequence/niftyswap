/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";

import type { ERC1155Mock } from "../ERC1155Mock";

export class ERC1155Mock__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ERC1155Mock> {
    return super.deploy(overrides || {}) as Promise<ERC1155Mock>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): ERC1155Mock {
    return super.attach(address) as ERC1155Mock;
  }
  connect(signer: Signer): ERC1155Mock__factory {
    return super.connect(signer) as ERC1155Mock__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ERC1155Mock {
    return new Contract(address, _abi, signerOrProvider) as ERC1155Mock;
  }
}

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "_owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_operator",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "_approved",
        type: "bool",
      },
    ],
    name: "ApprovalForAll",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "_operator",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "_ids",
        type: "uint256[]",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "_amounts",
        type: "uint256[]",
      },
    ],
    name: "TransferBatch",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "_operator",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "_id",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    name: "TransferSingle",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "_uri",
        type: "string",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "_id",
        type: "uint256",
      },
    ],
    name: "URI",
    type: "event",
  },
  {
    stateMutability: "nonpayable",
    type: "fallback",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_owner",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_id",
        type: "uint256",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address[]",
        name: "_owners",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "_ids",
        type: "uint256[]",
      },
    ],
    name: "balanceOfBatch",
    outputs: [
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "_ids",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "_values",
        type: "uint256[]",
      },
    ],
    name: "batchBurnMock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "_ids",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "_values",
        type: "uint256[]",
      },
      {
        internalType: "bytes",
        name: "_data",
        type: "bytes",
      },
    ],
    name: "batchMintMock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_id",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_value",
        type: "uint256",
      },
    ],
    name: "burnMock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "_operator",
        type: "address",
      },
    ],
    name: "isApprovedForAll",
    outputs: [
      {
        internalType: "bool",
        name: "isOperator",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_id",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_value",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "_data",
        type: "bytes",
      },
    ],
    name: "mintMock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "_ids",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "_amounts",
        type: "uint256[]",
      },
      {
        internalType: "bytes",
        name: "_data",
        type: "bytes",
      },
    ],
    name: "safeBatchTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_from",
        type: "address",
      },
      {
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_id",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "_data",
        type: "bytes",
      },
    ],
    name: "safeTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_operator",
        type: "address",
      },
      {
        internalType: "bool",
        name: "_approved",
        type: "bool",
      },
    ],
    name: "setApprovalForAll",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "_interfaceID",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_id",
        type: "uint256",
      },
    ],
    name: "uri",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50611ea7806100206000396000f3fe608060405234801561001057600080fd5b50600436106100d35760003560e01c8063a22cb46511610081578063d7a0ad901161005b578063d7a0ad90146101de578063e985e9c5146101f1578063f242432a14610204576100d3565b8063a22cb465146101a5578063a3f091f5146101b8578063bd7a6c41146101cb576100d3565b80632eb2c2d6116100b25780632eb2c2d61461015d578063437ecbe9146101725780634e1273f414610185576100d3565b8062fdd58e146100f457806301ffc9a71461011d5780630e89341c1461013d575b60405162461bcd60e51b81526004016100eb90611bdb565b60405180910390fd5b610107610102366004611972565b610217565b6040516101149190611c38565b60405180910390f35b61013061012b366004611ae1565b61023d565b6040516101149190611b7d565b61015061014b366004611b21565b610250565b6040516101149190611b88565b61017061016b366004611729565b610367565b005b61017061018036600461199b565b610424565b610198610193366004611a20565b610434565b6040516101149190611b39565b6101706101b3366004611938565b61054c565b6101706101c63660046119cd565b6105d8565b6101706101d9366004611832565b6105ea565b6101706101ec3660046118a3565b6105f5565b6101306101ff3660046116f7565b610601565b6101706102123660046117cf565b61062f565b6001600160a01b0391909116600090815260208181526040808320938352929052205490565b6000610248826106e5565b90505b919050565b6060600261025d83610742565b60405160200180838054600181600116156101000203166002900480156102bb5780601f106102995761010080835404028352918201916102bb565b820191906000526020600020905b8154815290600101906020018083116102a7575b5050825160208401908083835b602083106102e75780518252601f1990920191602091820191016102c8565b5181516020939093036101000a60001901801990911692169190911790527f2e6a736f6e000000000000000000000000000000000000000000000000000000920191825250604080518083037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe50181526005909201905295945050505050565b336001600160a01b038616148061038357506103838533610601565b6103be5760405162461bcd60e51b815260040180806020018281038252602f815260200180611d9a602f913960400191505060405180910390fd5b6001600160a01b0384166104035760405162461bcd60e51b8152600401808060200182810382526030815260200180611d0e6030913960400191505060405180910390fd5b61040f85858585610850565b61041d858585855a86610afb565b5050505050565b61042f838383610d24565b505050565b606081518351146104765760405162461bcd60e51b815260040180806020018281038252602c815260200180611d6e602c913960400191505060405180910390fd5b6060835167ffffffffffffffff8111801561049057600080fd5b506040519080825280602002602001820160405280156104ba578160200160208202803683370190505b50905060005b8451811015610544576000808683815181106104d857fe5b60200260200101516001600160a01b03166001600160a01b03168152602001908152602001600020600085838151811061050e57fe5b602002602001015181526020019081526020016000205482828151811061053157fe5b60209081029190910101526001016104c0565b509392505050565b3360008181526001602090815260408083206001600160a01b0387168085529083529281902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016861515908117909155815190815290519293927f17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31929181900390910190a35050565b6105e484848484610db5565b50505050565b61042f838383610e50565b6105e48484848461101b565b6001600160a01b03918216600090815260016020908152604080832093909416825291909152205460ff1690565b336001600160a01b038616148061064b575061064b8533610601565b6106865760405162461bcd60e51b815260040180806020018281038252602a815260200180611caf602a913960400191505060405180910390fd5b6001600160a01b0384166106cb5760405162461bcd60e51b815260040180806020018281038252602b815260200180611c84602b913960400191505060405180910390fd5b6106d7858585856111f0565b61041d858585855a866112cc565b60007fffffffff0000000000000000000000000000000000000000000000000000000082167f0e89341c0000000000000000000000000000000000000000000000000000000014156107395750600161024b565b6102488261146f565b606081610783575060408051808201909152600181527f3000000000000000000000000000000000000000000000000000000000000000602082015261024b565b818060005b821561079c57600101600a83049250610788565b60608167ffffffffffffffff811180156107b557600080fd5b506040519080825280601f01601f1916602001820160405280156107e0576020820181803683370190505b50905060001982015b831561084657600a840660300160f81b8282806001900393508151811061080c57fe5b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a905350600a840493506107e9565b5095945050505050565b80518251146108905760405162461bcd60e51b8152600401808060200182810382526035815260200180611cd96035913960400191505060405180910390fd5b815160005b81811015610a1a5761090b8382815181106108ac57fe5b6020026020010151600080896001600160a01b03166001600160a01b0316815260200190815260200160002060008785815181106108e657fe5b60200260200101518152602001908152602001600020546114cc90919063ffffffff16565b600080886001600160a01b03166001600160a01b03168152602001908152602001600020600086848151811061093d57fe5b60200260200101518152602001908152602001600020819055506109c583828151811061096657fe5b6020026020010151600080886001600160a01b03166001600160a01b0316815260200190815260200160002060008785815181106109a057fe5b602002602001015181526020019081526020016000205461152990919063ffffffff16565b600080876001600160a01b03166001600160a01b0316815260200190815260200160002060008684815181106109f757fe5b602090810291909101810151825281019190915260400160002055600101610895565b50836001600160a01b0316856001600160a01b0316336001600160a01b03167f4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb8686604051808060200180602001838103835285818151815260200191508051906020019060200280838360005b83811015610aa0578181015183820152602001610a88565b50505050905001838103825284818151815260200191508051906020019060200280838360005b83811015610adf578181015183820152602001610ac7565b5050505090500194505050505060405180910390a45050505050565b610b0d856001600160a01b031661158a565b15610d1c576000856001600160a01b031663bc197c8184338a8989886040518763ffffffff1660e01b815260040180866001600160a01b03168152602001856001600160a01b03168152602001806020018060200180602001848103845287818151815260200191508051906020019060200280838360005b83811015610b9e578181015183820152602001610b86565b50505050905001848103835286818151815260200191508051906020019060200280838360005b83811015610bdd578181015183820152602001610bc5565b50505050905001848103825285818151815260200191508051906020019080838360005b83811015610c19578181015183820152602001610c01565b50505050905090810190601f168015610c465780820380516001836020036101000a031916815260200191505b5098505050505050505050602060405180830381600088803b158015610c6b57600080fd5b5087f1158015610c7f573d6000803e3d6000fd5b50505050506040513d6020811015610c9657600080fd5b505190507fffffffff0000000000000000000000000000000000000000000000000000000081167fbc197c810000000000000000000000000000000000000000000000000000000014610d1a5760405162461bcd60e51b815260040180806020018281038252603f815260200180611df9603f913960400191505060405180910390fd5b505b505050505050565b6001600160a01b038316600090815260208181526040808320858452909152902054610d5090826114cc565b6001600160a01b03841660008181526020818152604080832087845282528083209490945583518681529081018590528351919333927fc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f629281900390910190a4505050565b6001600160a01b038416600090815260208181526040808320868452909152902054610de19083611529565b6001600160a01b038516600081815260208181526040808320888452825280832094909455835187815290810186905283519293919233927fc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62928290030190a46105e460008585855a866112cc565b815181518114610e915760405162461bcd60e51b8152600401808060200182810382526030815260200180611d3e6030913960400191505060405180910390fd5b60005b81811015610f3a57610ee5838281518110610eab57fe5b6020026020010151600080886001600160a01b03166001600160a01b0316815260200190815260200160002060008785815181106108e657fe5b600080876001600160a01b03166001600160a01b031681526020019081526020016000206000868481518110610f1757fe5b602090810291909101810151825281019190915260400160002055600101610e94565b5060006001600160a01b0316846001600160a01b0316336001600160a01b03167f4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb8686604051808060200180602001838103835285818151815260200191508051906020019060200280838360005b83811015610fc1578181015183820152602001610fa9565b50505050905001838103825284818151815260200191508051906020019060200280838360005b83811015611000578181015183820152602001610fe8565b5050505090500194505050505060405180910390a450505050565b815183511461105b5760405162461bcd60e51b8152600401808060200182810382526030815260200180611dc96030913960400191505060405180910390fd5b825160005b81811015611106576110b184828151811061107757fe5b6020026020010151600080896001600160a01b03166001600160a01b0316815260200190815260200160002060008885815181106109a057fe5b600080886001600160a01b03166001600160a01b0316815260200190815260200160002060008784815181106110e357fe5b602090810291909101810151825281019190915260400160002055600101611060565b50846001600160a01b031660006001600160a01b0316336001600160a01b03167f4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb8787604051808060200180602001838103835285818151815260200191508051906020019060200280838360005b8381101561118d578181015183820152602001611175565b50505050905001838103825284818151815260200191508051906020019060200280838360005b838110156111cc5781810151838201526020016111b4565b5050505090500194505050505060405180910390a461041d60008686865a87610afb565b6001600160a01b03841660009081526020818152604080832085845290915290205461121c90826114cc565b6001600160a01b038086166000908152602081815260408083208784528252808320949094559186168152808252828120858252909152205461125f9082611529565b6001600160a01b03808516600081815260208181526040808320888452825291829020949094558051868152938401859052805191939288169233927fc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62929181900390910190a450505050565b6112de856001600160a01b031661158a565b15610d1c576000856001600160a01b031663f23a6e6184338a8989886040518763ffffffff1660e01b815260040180866001600160a01b03168152602001856001600160a01b0316815260200184815260200183815260200180602001828103825283818151815260200191508051906020019080838360005b83811015611370578181015183820152602001611358565b50505050905090810190601f16801561139d5780820380516001836020036101000a031916815260200191505b509650505050505050602060405180830381600088803b1580156113c057600080fd5b5087f11580156113d4573d6000803e3d6000fd5b50505050506040513d60208110156113eb57600080fd5b505190507fffffffff0000000000000000000000000000000000000000000000000000000081167ff23a6e610000000000000000000000000000000000000000000000000000000014610d1a5760405162461bcd60e51b815260040180806020018281038252603a815260200180611e38603a913960400191505060405180910390fd5b60007fffffffff0000000000000000000000000000000000000000000000000000000082167fd9b67a260000000000000000000000000000000000000000000000000000000014156114c35750600161024b565b610248826115c1565b600082821115611523576040805162461bcd60e51b815260206004820152601760248201527f536166654d617468237375623a20554e444552464c4f57000000000000000000604482015290519081900360640190fd5b50900390565b600082820183811015611583576040805162461bcd60e51b815260206004820152601660248201527f536166654d617468236164643a204f564552464c4f5700000000000000000000604482015290519081900360640190fd5b9392505050565b6000813f801580159061158357507fc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470141592915050565b7fffffffff0000000000000000000000000000000000000000000000000000000081167f01ffc9a70000000000000000000000000000000000000000000000000000000014919050565b80356001600160a01b038116811461024b57600080fd5b600082601f830112611632578081fd5b813561164561164082611c65565b611c41565b81815291506020808301908481018184028601820187101561166657600080fd5b60005b8481101561168557813584529282019290820190600101611669565b505050505092915050565b600082601f8301126116a0578081fd5b813567ffffffffffffffff8111156116b457fe5b6116c76020601f19601f84011601611c41565b91508082528360208285010111156116de57600080fd5b8060208401602084013760009082016020015292915050565b60008060408385031215611709578182fd5b6117128361160b565b91506117206020840161160b565b90509250929050565b600080600080600060a08688031215611740578081fd5b6117498661160b565b94506117576020870161160b565b9350604086013567ffffffffffffffff80821115611773578283fd5b61177f89838a01611622565b94506060880135915080821115611794578283fd5b6117a089838a01611622565b935060808801359150808211156117b5578283fd5b506117c288828901611690565b9150509295509295909350565b600080600080600060a086880312156117e6578081fd5b6117ef8661160b565b94506117fd6020870161160b565b93506040860135925060608601359150608086013567ffffffffffffffff811115611826578182fd5b6117c288828901611690565b600080600060608486031215611846578283fd5b61184f8461160b565b9250602084013567ffffffffffffffff8082111561186b578384fd5b61187787838801611622565b9350604086013591508082111561188c578283fd5b5061189986828701611622565b9150509250925092565b600080600080608085870312156118b8578384fd5b6118c18561160b565b9350602085013567ffffffffffffffff808211156118dd578485fd5b6118e988838901611622565b945060408701359150808211156118fe578384fd5b61190a88838901611622565b9350606087013591508082111561191f578283fd5b5061192c87828801611690565b91505092959194509250565b6000806040838503121561194a578182fd5b6119538361160b565b915060208301358015158114611967578182fd5b809150509250929050565b60008060408385031215611984578182fd5b61198d8361160b565b946020939093013593505050565b6000806000606084860312156119af578283fd5b6119b88461160b565b95602085013595506040909401359392505050565b600080600080608085870312156119e2578384fd5b6119eb8561160b565b93506020850135925060408501359150606085013567ffffffffffffffff811115611a14578182fd5b61192c87828801611690565b60008060408385031215611a32578081fd5b823567ffffffffffffffff80821115611a49578283fd5b818501915085601f830112611a5c578283fd5b8135611a6a61164082611c65565b80828252602080830192508086018a828387028901011115611a8a578788fd5b8796505b84871015611ab357611a9f8161160b565b845260019690960195928101928101611a8e565b509096508701359350505080821115611aca578283fd5b50611ad785828601611622565b9150509250929050565b600060208284031215611af2578081fd5b81357fffffffff0000000000000000000000000000000000000000000000000000000081168114611583578182fd5b600060208284031215611b32578081fd5b5035919050565b6020808252825182820181905260009190848201906040850190845b81811015611b7157835183529284019291840191600101611b55565b50909695505050505050565b901515815260200190565b6000602080835283518082850152825b81811015611bb457858101830151858201604001528201611b98565b81811115611bc55783604083870101525b50601f01601f1916929092016040019392505050565b60208082526027908201527f455243313135354d6574614d696e744275726e4d6f636b3a20494e56414c494460408201527f5f4d4554484f4400000000000000000000000000000000000000000000000000606082015260800190565b90815260200190565b60405181810167ffffffffffffffff81118282101715611c5d57fe5b604052919050565b600067ffffffffffffffff821115611c7957fe5b506020908102019056fe4552433131353523736166655472616e7366657246726f6d3a20494e56414c49445f524543495049454e544552433131353523736166655472616e7366657246726f6d3a20494e56414c49445f4f50455241544f5245524331313535235f7361666542617463685472616e7366657246726f6d3a20494e56414c49445f4152524159535f4c454e47544845524331313535237361666542617463685472616e7366657246726f6d3a20494e56414c49445f524543495049454e54455243313135354d696e744275726e2362617463684275726e3a20494e56414c49445f4152524159535f4c454e475448455243313135352362616c616e63654f6642617463683a20494e56414c49445f41525241595f4c454e47544845524331313535237361666542617463685472616e7366657246726f6d3a20494e56414c49445f4f50455241544f52455243313135354d696e744275726e2362617463684d696e743a20494e56414c49445f4152524159535f4c454e47544845524331313535235f63616c6c6f6e45524331313535426174636852656365697665643a20494e56414c49445f4f4e5f524543454956455f4d45535341474545524331313535235f63616c6c6f6e4552433131353552656365697665643a20494e56414c49445f4f4e5f524543454956455f4d455353414745a2646970667358221220d9daacb25aa1d845a6832ed3119942ca0ead7b8adea6c7eda48b7b0b16cd9c7664736f6c63430007040033";
