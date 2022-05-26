# NFT Marketplace Flow

```mermaid
classDiagram
  direction TB
  MarketplaceBase <|-- ERC721MarketplaceBase
  ERC721MarketplaceBase <|-- ERC721Marketplace
  Addresses <.. ERC721MarketplaceBase
  ERC721MarketplaceBase o-- Sale
  class ERC721Marketplace {
    +createSale(contractAddr, tokenId, price)
    +||payable|| buy(contractAddr, tokenId)
    +cancelSale(contractAddr, tokenId)
    +cancelSaleWhenPaused(contractAddr, tokenId)
  }
  class Sale {
    <<struct>>
    +address seller
    +uint256 startPrice
    +uint256 endPrice
    +uint256 startedAt
    +uint256 duration
  }
  class ERC721MarketplaceBase {
    <<abstract>>
    -map~uint256,Sale~ tokenIdToSales
    -map~address,uint256[]~ saleTokenIdsBySeller
    +map~address,uint256[]~ saleTokenIds
    -_addSale(contractAddr, tokenId, sale)
    -_cancelSale(contractAddr, tokenId)
    -_buy(contractAddr, tokenId)
    -_removeSale(contractAddr, tokenId)
    -_transferFrom(contractAddr, owner, receiver, tokenId)
    +getSaleTokens(contractAddr) uint256[]
    +tokenOfOwnerByIndex(contractAddr, owner, index) uint256
    +walletOfOwner(contractAddr, owner) uint256[]
    +getSaleTokensBySeller(seller, contractAddr) uint256[]
    +getCurrentPrice(contractAddr, tokenId) uint256
    +getSale(contractAddr, tokenId) (address, uint256, uint256, uint256)
    +getSales(contractAddr) (address[], uint256[], uint256[], uint256[])
    +||event|| SaleCreated(contractAddr, tokenId, startPrice, endPrice, time, duration)
    +||event|| SaleSuccessful(contractAddr, tokenId, price, buyer)
    +||event|| SaleCancelled(contractAddr, tokenId)
    +||modifier|| isProperERC721(contractAddr)
    +||modifier|| isProperERC721Enumerable(contractAddr)
    +||modifier|| onSale(contractAddr, tokenId)
    +||modifier|| notOnSale(contractAddr, tokenId)
    +||modifier|| owningToken(contractAddr, _tokenId)
    +||modifier|| onlySeller(contractAddr, tokenId)
    +||modifier|| onlyBuyer(contractAddr, tokenId)
  }
  class MarketplaceBase {
    +address addressesContractAddr
    +||modifier|| verified(contractAddr)
    +setAddressesContractAddr(contractAddr)
  }
  class Addresses {
    -address[] contracts
    -map~address,bool~ verified

    +existingContract(contractAddr) bool
    +addContract(contractAddr)
    +removeContract(contractAddr)
    +verify(contractAddr)
    +getContracts() address[]
    +getVerifiedContracts() address[]
    +isVerified(contractAddr) bool
    +||modifier|| exists(contractAddr)
    +||modifier|| doesNotExist(contractAddr)
  }
```

```mermaid
classDiagram
  direction TB
  MarketplaceBase <|-- ERC1155MarketplaceBase
  ERC1155MarketplaceBase <|-- ERC1155Marketplace
  Addresses <.. ERC1155MarketplaceBase
  ERC1155MarketplaceBase o-- Sale
  class ERC1155Marketplace {
    +createSale(createSaleReq)
    +||payable|| buy(contractAddr, tokenId, sale)
    +cancelSale(contractAddr, tokenId, sale)
    +||payable|| makeOffer(contractAddr, tokenId, sale, price, amount)
  }
  class Sale {
    <<struct>>
    +address seller
    +uint256 startPrice
    +uint256 endPrice
    +uint256 amount
    +uint256 startedAt
    +uint256 duration
    +address[] offerers
    +uint256[] prices
    +uint256[] amounts
    +uint256[] times
  }
  class ERC1155MarketplaceBase {
    <<abstract>>
    -map~uint256,Sale[]~ tokenIdToSales
    -map~address,uint256[]~ saleTokenIds
    -map~address,uint256[]~ saleTokenIdsBySeller
    -map~address,Sale[]~ saleTokensBySeller
    -_addSale(contractAddr, tokenId, sale)
    -_escrow(contractAddr, tokenId, amount, seller)
    -_transfer(contractAddr, tokenId, amount)
    -_buy(price, seller)
    -_cancelSale(contractAddr, tokenId, sale)
    +onERC1155Received(operator, from, id, value, data)
    +onERC1155BatchReceived(operator, from, ids, values, data)
    +getSalesByNFT(contractAddr, tokenId) (address[], uint256[], uint256[], uint256[], uint256[], uint256[], uint256[])
    +getSaleTokens(contractAddr) uint256[]
    +getSalesBySellerNFT(seller, contractAddr, tokenId) (uint256[], uint256[], uint256[], uint256[], uint256[], uint256[])
    +getSaleTokensBySeller(contractAddr, seller) uint256[]
    +getCurrentPrice(contractAddr, tokenId, sale) uint256
    +||event|| SaleCreated(contractAddr, tokenId, startPrice, endPrice, amount, time, duration)
    +||event|| SaleSuccessful(contractAddr, tokenId, sale, price, buyer)
    +||event|| SaleCancelled(contractAddr, tokenId, sale)
    +||modifier|| isProperERC1155(contractAddr)
    +||modifier|| onSale(contractAddr, tokenId, sale)
    +||modifier|| notOnSale(contractAddr, tokenId)
    +||modifier|| owningToken(contractAddr, tokenId, amount)
    +||modifier|| onlySeller(seller)
    +||modifier|| onlyBuyer(seller)
  }
  class MarketplaceBase {
    +address addressesContractAddr
    +||modifier|| verified(contractAddr)
    +setAddressesContractAddr(contractAddr)
  }
  class Addresses {
    -address[] contracts
    -map~address,bool~ verified

    +existingContract(contractAddr) bool
    +addContract(contractAddr)
    +removeContract(contractAddr)
    +verify(contractAddr)
    +getContracts() address[]
    +getVerifiedContracts() address[]
    +isVerified(contractAddr) bool
    +||modifier|| exists(contractAddr)
    +||modifier|| doesNotExist(contractAddr)
  }
```

```mermaid
sequenceDiagram
    participant User 1
    participant User 2
    participant Marketplace Owner
    participant Addresses
    participant ERC721Marketplace
    participant ERC721 NFT
    Marketplace Owner->>ERC721Marketplace: Set Addresses Smart Contract Address
    Marketplace Owner->>Addresses: Register NFT Smart Contract
    User 1->>ERC721Marketplace: Get NFT Info, Balance Info in ERC721 NFT Contract
    ERC721Marketplace->>ERC721 NFT: Get NFT Info, Balance Info
    ERC721 NFT-->>ERC721Marketplace: NFT Info, Balance Info
    ERC721Marketplace-->>User 1: NFT Info, Balance Info
    User 1->>ERC721 NFT: Approve NFT of tokenId to Marketplace
    User 1->>ERC721Marketplace: Transfer NFT of tokenId to User 2 in ERC721 NFT Contract
    ERC721Marketplace->>ERC721 NFT: Transfer NFT of tokenId<br/>from User 1 to User 2
    Marketplace Owner->>Addresses: Verify NFT Smart Contract
    User 1->>ERC721Marketplace: Create/Cancel Sale with tokenId in ERC721 NFT Contract
    ERC721Marketplace->>ERC721 NFT: Transfer NFT of tokenId<br/>from User 1/Marketplace<br/>to Marketplace/User1
    User 2->>ERC721Marketplace: Get Sale Tokens in ERC721 NFT Contract
    ERC721Marketplace-->>User 2: Sale Tokens in ERC721 NFT Contract
    User 2->>ERC721Marketplace: Get Sale Info of NFT of tokenId in ERC721 NFT Contract
    ERC721Marketplace-->>User 2: Sale Info of NFT of tokenId in ERC721 NFT Contract
    User 2->>ERC721Marketplace: Purchase NFT of tokenId in ERC721 NFT Contract
    ERC721Marketplace->>ERC721 NFT: Transfer NFT of tokenId<br/>from Marketplace<br/>to User 2
    ERC721Marketplace-->>User 1: Transfer coins of the price to User 1
```

```mermaid
sequenceDiagram
    participant User 1
    participant User 2
    participant Marketplace Owner
    participant Addresses
    participant ERC1155Marketplace
    participant ERC1155 NFT
    Marketplace Owner->>ERC1155Marketplace: Set Addresses Smart Contract Address
    Marketplace Owner->>Addresses: Register NFT Smart Contract
    User 1->>ERC1155Marketplace: Get NFT Info, Balance Info in ERC1155 NFT Contract
    ERC1155Marketplace->>ERC1155 NFT: Get NFT Info, Balance Info
    ERC1155 NFT-->>ERC1155Marketplace: NFT Info, Balance Info
    ERC1155Marketplace-->>User 1: NFT Info, Balance Info
    User 1->>ERC1155 NFT: Approve NFT of tokenId to Marketplace
    User 1->>ERC1155Marketplace: Transfer NFT of tokenId to User 2 in ERC1155 NFT Contract
    ERC1155Marketplace->>ERC1155 NFT: Transfer NFT of tokenId<br/>from User 1 to User 2
    Marketplace Owner->>Addresses: Verify NFT Smart Contract
    User 1->>ERC1155Marketplace: Create/Cancel Sale with tokenId in ERC1155 NFT Contract
    ERC1155Marketplace->>ERC1155 NFT: Transfer NFT of tokenId<br/>from User 1/Marketplace<br/>to Marketplace/User1
    User 2->>ERC1155Marketplace: Get Sale Tokens in ERC1155 NFT Contract
    ERC1155Marketplace-->>User 2: Sale Tokens in ERC1155 NFT Contract
    User 2->>ERC1155Marketplace: Get Sale Info of NFT of tokenId in ERC1155 NFT Contract
    ERC1155Marketplace-->>User 2: Sale Info of NFT of tokenId in ERC1155 NFT Contract
    User 2->>ERC1155Marketplace: Purchase NFT of tokenId in ERC1155 NFT Contract
    ERC1155Marketplace->>ERC1155 NFT: Transfer NFT of tokenId<br/>from Marketplace<br/>to User 2
    ERC1155Marketplace-->>User 1: Transfer coins of the price to User 1
```

# Smart Contract Project Setup and Test

This project is the NFT Marketplace Smart Contract integrating tools for unit test using Hardhat.

# Smart Contract Project Setup

Please install dependency modules
```shell
yarn
```

Please compile Smart Contracts
```shell
yarn compile
```

# Project Test

You can test Smart Contracts using
```shell
yarn test
```

# Deploy Smart Contracts

You can deploy Smart Contracts on the hardhat by
```shell
npx hardhat run scripts/deploy.js
```

First, you should change the .env.example file name as .env
Before deploying Smart contracts in the real networks like Ethereum or Rinkeby, you should add the chain info in the hardhat.config.js file

```javascript
{
  ...
  ropsten: {
    url: `https://ropsten.infura.io/v3/${process.env.INFURA_ID}`,
    tags: ["nft", "marketplace", "test"],
    chainId: 3,
    accounts: real_accounts,
    gas: 2100000,
    gasPrice: 8000000000
  },
  ...
}
```

You should add your wallet private key to .env file to make deploy transaction with your wallet

```javascript
...
PRIVATE_KEY=123123123123123
...
```

After that, you can deploy the Smart Contracts on the chain by

```shell
npx hardhat run scripts/deploy.js --network ropsten
```