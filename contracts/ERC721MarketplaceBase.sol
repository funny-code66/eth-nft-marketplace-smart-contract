// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./MarketplaceBase.sol";

abstract contract ERC721MarketplaceBase is MarketplaceBase {
    struct Sale {
        address seller;
        uint256 payment;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startedAt;
        uint256 duration;
    }

    struct Auction {
        uint256 payment;
        address auctioneer;
        address[] bidders;
        uint256[] bidPrices;
    }

    struct Offer {
        address offerer;
        uint256 offerPrice;
    }

    mapping(address => mapping(uint256 => Sale)) internal tokenIdToSales;
    mapping(address => mapping(uint256 => Offer[])) internal tokenIdToOffers;
    mapping(address => mapping(uint256 => Auction)) internal tokenIdToAuctions;

    event SaleCreated(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 time,
        uint256 duration
    );
    event SaleSuccessful(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 price,
        address buyer
    );
    event SaleCancelled(address contractAddr, uint256 tokenId);
    event OfferCreated(
        address contractAddr,
        uint256 tokenId,
        uint256 price,
        address offerer
    );
    event OfferCancelled(
        address contractAddr,
        uint256 tokenId,
        uint256 price,
        address offerer
    );
    event OfferAccepted(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 price,
        address offerer
    );
    event AuctionCreated(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        address auctioneer
    );
    event AuctionCancelled(
        address contractAddr,
        uint256 tokenId,
        address auctioneer
    );
    event AuctionBid(
        address contractAddr,
        uint256 tokenId,
        address bidder,
        uint256 bidPrice
    );
    event CancelBid(address contractAddr, uint256 tokenId, address bidder);

    modifier onSale(address contractAddr, uint256 tokenId) {
        require(
            tokenIdToSales[contractAddr][tokenId].startPrice > 0,
            "Not On Sale"
        );
        _;
    }

    modifier onAuction(address contractAddr, uint256 tokenId) {
        require(
            tokenIdToAuctions[contractAddr][tokenId].payment > 0,
            "Not On Sale"
        );
        _;
    }

    modifier owningToken(address contractAddr, uint256 tokenId) {
        require(
            IERC721(contractAddr).ownerOf(tokenId) == msg.sender,
            "Not Owner of Token"
        );
        _;
    }

    modifier onlySeller(address contractAddr, uint256 tokenId) {
        require(
            tokenIdToSales[contractAddr][tokenId].seller == msg.sender,
            "Caller Is Not Seller"
        );
        _;
    }

    modifier onlyBuyer(address contractAddr, uint256 tokenId) {
        require(
            tokenIdToSales[contractAddr][tokenId].seller != msg.sender,
            "Caller Is Seller"
        );
        _;
    }

    function removeAt(Offer[] storage self, uint256 index) internal {
        self[index] = self[self.length - 1];
        self.pop();
    }

    function _removeSale(address contractAddr, uint256 tokenId) internal {
        uint256 i = ArrayLibrary.findIndex(saleTokenIds[contractAddr], tokenId);
        require(i < saleTokenIds[contractAddr].length, "No Sale for this NFT");
        ArrayLibrary.removeAt(saleTokenIds[contractAddr], i);
        Sale memory sale = tokenIdToSales[contractAddr][tokenId];
        ArrayLibrary.removeAt(
            saleTokenIdsBySeller[sale.seller][contractAddr],
            ArrayLibrary.findIndex(
                saleTokenIdsBySeller[sale.seller][contractAddr],
                tokenId
            )
        );
        uint256 length = tokenIdToOffers[contractAddr][tokenId].length;
        for (i = 0; i < length; ++i) {
            Offer memory curOffer = tokenIdToOffers[contractAddr][tokenId][i];
            claimable[curOffer.offerer][sale.payment - 1] += curOffer
                .offerPrice;
        }
        delete tokenIdToOffers[contractAddr][tokenId];
        delete tokenIdToSales[contractAddr][tokenId];
    }

    function _cancelAuction(address contractAddr, uint256 tokenId) internal {
        uint256 i;
        uint256 length = tokenIdToAuctions[contractAddr][tokenId]
            .bidders
            .length;
        for (i = 0; i < length; ++i) {
            claimable[tokenIdToAuctions[contractAddr][tokenId].bidders[i]][
                tokenIdToAuctions[contractAddr][tokenId].payment - 1
            ] += tokenIdToAuctions[contractAddr][tokenId].bidPrices[i];
        }
        delete tokenIdToAuctions[contractAddr][tokenId];
        ArrayLibrary.removeAt(
            auctionTokenIds[contractAddr],
            ArrayLibrary.findIndex(auctionTokenIds[contractAddr], tokenId)
        );
        ArrayLibrary.removeAt(
            auctionTokenIdsBySeller[msg.sender][contractAddr],
            ArrayLibrary.findIndex(
                auctionTokenIdsBySeller[msg.sender][contractAddr],
                tokenId
            )
        );
    }

    function getSale(address contractAddr, uint256 tokenId)
        external
        view
        isProperContract(contractAddr)
        onSale(contractAddr, tokenId)
        returns (
            Sale memory sale,
            Offer[] memory offers,
            uint256 currentPrice
        )
    {
        sale = tokenIdToSales[contractAddr][tokenId];
        offers = tokenIdToOffers[contractAddr][tokenId];
        currentPrice = getCurrentPrice(contractAddr, tokenId);
    }

    function getSales(address contractAddr)
        external
        view
        isProperContract(contractAddr)
        returns (
            Sale[] memory sales,
            Offer[][] memory offers,
            uint256[] memory currentPrices
        )
    {
        uint256 i;
        uint256 length = saleTokenIds[contractAddr].length;
        sales = new Sale[](length);
        offers = new Offer[][](length);
        currentPrices = new uint256[](length);
        for (i = 0; i < length; ++i) {
            uint256 tokenId = saleTokenIds[contractAddr][i];
            sales[i] = tokenIdToSales[contractAddr][tokenId];
            offers[i] = tokenIdToOffers[contractAddr][tokenId];
            currentPrices[i] = getCurrentPrice(contractAddr, tokenId);
        }
    }

    function getSalesBySeller(address contractAddr, address owner)
        external
        view
        isProperContract(contractAddr)
        returns (
            Sale[] memory sales,
            Offer[][] memory offers,
            uint256[] memory currentPrices
        )
    {
        uint256 i;
        uint256 length = saleTokenIdsBySeller[owner][contractAddr].length;
        sales = new Sale[](length);
        offers = new Offer[][](length);
        currentPrices = new uint256[](length);
        for (i = 0; i < length; ++i) {
            uint256 tokenId = saleTokenIdsBySeller[owner][contractAddr][i];
            sales[i] = tokenIdToSales[contractAddr][tokenId];
            offers[i] = tokenIdToOffers[contractAddr][tokenId];
            currentPrices[i] = getCurrentPrice(contractAddr, tokenId);
        }
    }

    function getAuctions(address contractAddr)
        external
        view
        isProperContract(contractAddr)
        returns (Auction[] memory auctions)
    {
        uint256 i;
        uint256 length = auctionTokenIds[contractAddr].length;
        auctions = new Auction[](length);
        for (i = 0; i < length; ++i) {
            uint256 tokenId = saleTokenIds[contractAddr][i];
            auctions[i] = tokenIdToAuctions[contractAddr][tokenId];
        }
    }

    function getAuctionsBySeller(address contractAddr, address owner)
        external
        view
        isProperContract(contractAddr)
        returns (Auction[] memory auctions)
    {
        uint256 i;
        uint256 length = auctionTokenIdsBySeller[owner][contractAddr].length;
        auctions = new Auction[](length);
        for (i = 0; i < length; ++i) {
            uint256 tokenId = auctionTokenIdsBySeller[owner][contractAddr][i];
            auctions[i] = tokenIdToAuctions[contractAddr][tokenId];
        }
    }

    function getCurrentPrice(address contractAddr, uint256 tokenId)
        public
        view
        isProperContract(contractAddr)
        onSale(contractAddr, tokenId)
        returns (uint256)
    {
        Sale storage sale = tokenIdToSales[contractAddr][tokenId];
        if (block.timestamp >= sale.startedAt + sale.duration) {
            return sale.endPrice;
        }
        return
            sale.startPrice -
            ((sale.startPrice - sale.endPrice) *
                (block.timestamp - sale.startedAt)) /
            sale.duration;
    }
}
