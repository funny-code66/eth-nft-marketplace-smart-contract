// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "./MarketplaceBase.sol";

abstract contract ERC1155MarketplaceBase is MarketplaceBase, ERC1155Receiver {
    struct Sale {
        uint256 payment;
        address seller;
        uint256 startPrice;
        uint256 endPrice;
        uint256 amount;
        uint256 startedAt;
        uint256 duration;
        address[] offerers;
        uint256[] offerPrices;
        uint256[] offerAmounts;
    }

    struct SaleInfo {
        address seller;
        uint256 payment;
        uint256 startPrice;
        uint256 endPrice;
        uint256 amount;
        uint256 startedAt;
        uint256 duration;
    }

    struct Auction {
        uint256 payment;
        address auctioneer;
        uint256 amount;
        uint256 startedAt;
        address[] bidders;
        uint256[] bidPrices;
        uint256[] bidAmounts;
    }

    struct CreateSaleReq {
        address contractAddr;
        uint256 tokenId;
        uint256 payment;
        uint256 startPrice;
        uint256 endPrice;
        uint256 amount;
        uint256 duration;
    }

    struct BidReq {
        address contractAddr;
        uint256 tokenId;
        address auctioneer;
        uint256 startedAt;
        uint256 bidAmount;
    }

    mapping(address => mapping(uint256 => Sale[])) internal tokenIdToSales;

    mapping(address => mapping(address => mapping(uint256 => Sale[])))
        internal salesBySeller;

    mapping(address => mapping(uint256 => Auction[]))
        internal tokenIdToAuctions;

    mapping(address => mapping(address => mapping(uint256 => Auction[])))
        internal auctionsBySeller;

    event SaleCreated(
        address contractAddr,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endPrice,
        uint256 amount,
        uint256 time,
        uint256 duration
    );
    event SaleSuccessful(
        address contractAddr,
        uint256 tokenId,
        SaleInfo sale,
        uint256 price,
        address buyer
    );
    event SaleCancelled(address contractAddr, uint256 tokenId, SaleInfo sale);
    event OfferCreated(
        Sale sale,
        address contractAddr,
        uint256 tokenId,
        uint256 price,
        uint256 amount,
        address offerer
    );
    event OfferCancelled(
        Sale sale,
        address contractAddr,
        uint256 tokenId,
        uint256 amount,
        address offerer
    );
    event AuctionCreated(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 amount
    );
    event AuctionCancelled(
        address contractAddr,
        uint256 tokenId,
        uint256 startedAt,
        uint256 amount
    );
    event AuctionBid(
        address contractAddr,
        uint256 tokenId,
        address auctioneer,
        uint256 startedAt,
        uint256 bidPrice,
        uint256 bidAmount
    );
    event CancelBid(
        address contractAddr,
        uint256 tokenId,
        address auctioneer,
        uint256 startedAt,
        uint256 bidAmount
    );
    event BidAccepted(
        address contractAddr,
        uint256 tokenId,
        uint256 startedAt,
        uint256 amount
    );

    modifier onSale(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sale
    ) {
        uint256 i = _findSaleIndex(tokenIdToSales[contractAddr][tokenId], sale);
        require(
            i < tokenIdToSales[contractAddr][tokenId].length,
            "Not On Sale"
        );
        require(
            tokenIdToSales[contractAddr][tokenId][i].amount >= sale.amount,
            "Insufficient Token On Sale"
        );
        _;
    }

    modifier onAuction(
        address auctioneer,
        address contractAddr,
        uint256 tokenId,
        uint256 startedAt,
        uint256 amount
    ) {
        uint256 i = _findAuctionIndex(
            tokenIdToAuctions[contractAddr][tokenId],
            auctioneer,
            startedAt
        );
        require(
            i < tokenIdToAuctions[contractAddr][tokenId].length,
            "No Auction"
        );
        require(
            tokenIdToAuctions[contractAddr][tokenId][i].amount >= amount,
            "Insufficient Token on Auciton"
        );
        _;
    }

    function removeAt(Sale[] storage self, uint256 index) internal {
        self[index] = self[self.length - 1];
        self.pop();
    }

    function removeAt(Auction[] storage self, uint256 index) internal {
        self[index] = self[self.length - 1];
        self.pop();
    }

    function _addSale(
        address contractAddr,
        uint256 tokenId,
        Sale memory sale
    ) internal {
        if (tokenIdToSales[contractAddr][tokenId].length == 0) {
            saleTokenIds[contractAddr].push(tokenId);
        }
        tokenIdToSales[contractAddr][tokenId].push(sale);
        if (salesBySeller[msg.sender][contractAddr][tokenId].length == 0) {
            saleTokenIdsBySeller[msg.sender][contractAddr].push(tokenId);
        }
        salesBySeller[msg.sender][contractAddr][tokenId].push(sale);
    }

    function _removeSale(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sale
    ) internal {
        uint256 j;
        address seller = sale.seller;
        uint256 i = _findSaleIndex(tokenIdToSales[contractAddr][tokenId], sale);
        tokenIdToSales[contractAddr][tokenId][i].amount -= sale.amount;
        Sale memory curSale = tokenIdToSales[contractAddr][tokenId][i];
        uint256 length = curSale.offerers.length;
        for (j = 0; j < length; ++j) {
            if (curSale.offerAmounts[j] > curSale.amount) {
                claimable[curSale.offerers[j]][curSale.payment - 1] +=
                    (curSale.offerAmounts[j] - curSale.amount) *
                    curSale.offerPrices[j];
                tokenIdToSales[contractAddr][tokenId][i].offerAmounts[
                    j
                ] = curSale.amount;
            }
        }
        if (curSale.amount == 0) {
            removeAt(tokenIdToSales[contractAddr][tokenId], i);
            ArrayLibrary.removeAt(
                saleTokenIds[contractAddr],
                ArrayLibrary.findIndex(saleTokenIds[contractAddr], tokenId)
            );
        }
        i = _findSaleIndex(salesBySeller[seller][contractAddr][tokenId], sale);
        salesBySeller[seller][contractAddr][tokenId][i].amount -= sale.amount;
        if (salesBySeller[seller][contractAddr][tokenId][i].amount == 0) {
            removeAt(salesBySeller[seller][contractAddr][tokenId], i);
            ArrayLibrary.removeAt(
                saleTokenIdsBySeller[seller][contractAddr],
                ArrayLibrary.findIndex(
                    saleTokenIdsBySeller[seller][contractAddr],
                    tokenId
                )
            );
        }
    }

    function _getSaleInfo(Sale memory sale)
        internal
        pure
        returns (SaleInfo memory)
    {
        return
            SaleInfo(
                sale.seller,
                sale.payment,
                sale.startPrice,
                sale.endPrice,
                sale.amount,
                sale.startedAt,
                sale.duration
            );
    }

    function _isSameSale(Sale memory sale, SaleInfo memory saleInfo)
        internal
        pure
        returns (bool)
    {
        return
            sale.payment == saleInfo.payment &&
            sale.startPrice == saleInfo.startPrice &&
            sale.endPrice == saleInfo.endPrice &&
            sale.startedAt == saleInfo.startedAt &&
            sale.duration == saleInfo.duration &&
            sale.seller == saleInfo.seller;
    }

    function _removeOfferAt(Sale storage sale, uint256 index) internal {
        ArrayLibrary.removeAt(sale.offerers, index);
        ArrayLibrary.removeAt(sale.offerPrices, index);
        ArrayLibrary.removeAt(sale.offerAmounts, index);
    }

    function _createOffer(
        Sale[] storage sales,
        SaleInfo memory sale,
        uint256 price,
        uint256 amount,
        uint256 curPrice
    ) internal {
        //Finding sale of the NFT
        uint256 i = _findSaleIndex(sales, sale);
        require(i < sales.length, "Not On Sale");
        require(sales[i].amount >= amount, "Insufficient Token On Sale");

        //Finding Offer with current price
        uint256 j = ArrayLibrary.findIndex(sales[i].offerers, msg.sender);
        if (j < sales[i].offerers.length) {
            require(
                sales[i].offerPrices[j] == price,
                "Has Offer With Another Price"
            );
            sales[i].offerAmounts[j] += amount;
        } else {
            require(price < curPrice, "Invalid Offer Price");
            sales[i].offerers.push(msg.sender);
            sales[i].offerPrices.push(price);
            sales[i].offerAmounts.push(amount);
        }
    }

    function _removeOffer(
        Sale[] storage sales,
        SaleInfo memory sale,
        uint256 amount,
        address offerer
    ) internal {
        //Finding sale of the NFT
        uint256 i = _findSaleIndex(sales, sale);
        require(i < sales.length, "Not On Sale");
        //Finding Offer with current price
        uint256 j = ArrayLibrary.findIndex(sales[i].offerers, offerer);
        require(j < sales[i].offerers.length, "You have no offer");
        require(
            sales[i].offerAmounts[j] >= amount,
            "Insufficient offer to cancel"
        );
        sales[i].offerAmounts[j] -= amount;
        if (sales[i].offerAmounts[j] == 0) {
            _removeOfferAt(sales[i], j);
        }
    }

    function _bidAuction(
        Auction storage auction,
        uint256 bidPrice,
        uint256 bidAmount
    ) internal {
        auction.bidders.push(msg.sender);
        auction.bidPrices.push(bidPrice);
        auction.bidAmounts.push(bidAmount);
    }

    function _removeBid(
        Auction storage auction,
        address bidder,
        uint256 bidAmount
    ) internal {
        uint256 length = auction.bidders.length;
        uint256 i = ArrayLibrary.findIndex(auction.bidders, bidder);
        require(i < length, "No Bid");
        require(
            auction.bidAmounts[i] >= bidAmount,
            "Insufficient Bid to Cancel"
        );
        auction.bidAmounts[i] -= bidAmount;
        if (auction.bidAmounts[i] == 0) {
            ArrayLibrary.removeAt(auction.bidders, i);
            ArrayLibrary.removeAt(auction.bidPrices, i);
            ArrayLibrary.removeAt(auction.bidAmounts, i);
        }
    }

    function _findSaleIndex(Sale[] memory sales, SaleInfo memory sale)
        internal
        pure
        returns (uint256)
    {
        uint256 i;
        uint256 length = sales.length;
        for (i = 0; i < length && !_isSameSale(sales[i], sale); ++i) {}
        return i;
    }

    function _findAuctionIndex(
        Auction[] memory auctions,
        address auctioneer,
        uint256 startedAt
    ) internal pure returns (uint256) {
        uint256 i;
        uint256 length = auctions.length;
        for (
            i = 0;
            i < length &&
                (auctions[i].auctioneer != auctioneer ||
                    auctions[i].startedAt != startedAt);
            ++i
        ) {}
        return i;
    }

    function _cancelAuction(
        address contractAddr,
        uint256 tokenId,
        uint256 startedAt,
        uint256 amount
    ) internal {
        uint256 i = _findAuctionIndex(
            tokenIdToAuctions[contractAddr][tokenId],
            msg.sender,
            startedAt
        );
        uint256 j;
        uint256 length = tokenIdToAuctions[contractAddr][tokenId][i]
            .bidders
            .length;
        tokenIdToAuctions[contractAddr][tokenId][i].amount -= amount;
        for (j = 0; j < length; ++j) {
            if (
                tokenIdToAuctions[contractAddr][tokenId][i].bidAmounts[j] >
                tokenIdToAuctions[contractAddr][tokenId][i].amount
            ) {
                claimable[
                    tokenIdToAuctions[contractAddr][tokenId][i].bidders[j]
                ][tokenIdToAuctions[contractAddr][tokenId][i].payment - 1] +=
                    tokenIdToAuctions[contractAddr][tokenId][i].bidPrices[j] *
                    (tokenIdToAuctions[contractAddr][tokenId][i].bidAmounts[j] -
                        tokenIdToAuctions[contractAddr][tokenId][i].amount);
                _removeBid(
                    tokenIdToAuctions[contractAddr][tokenId][i],
                    tokenIdToAuctions[contractAddr][tokenId][i].bidders[j],
                    tokenIdToAuctions[contractAddr][tokenId][i].bidAmounts[j] -
                        tokenIdToAuctions[contractAddr][tokenId][i].amount
                );
            }
        }
        if (tokenIdToAuctions[contractAddr][tokenId][i].amount == 0) {
            removeAt(tokenIdToAuctions[contractAddr][tokenId], i);
            if (tokenIdToAuctions[contractAddr][tokenId].length == 0) {
                ArrayLibrary.removeAt(
                    auctionTokenIds[contractAddr],
                    ArrayLibrary.findIndex(
                        auctionTokenIds[contractAddr],
                        tokenId
                    )
                );
            }
        }
        i = _findAuctionIndex(
            auctionsBySeller[msg.sender][contractAddr][tokenId],
            msg.sender,
            startedAt
        );
        length = auctionsBySeller[msg.sender][contractAddr][tokenId][i]
            .bidders
            .length;
        auctionsBySeller[msg.sender][contractAddr][tokenId][i].amount -= amount;
        for (j = 0; j < length; ++j) {
            if (
                auctionsBySeller[msg.sender][contractAddr][tokenId][i]
                    .bidAmounts[j] >
                auctionsBySeller[msg.sender][contractAddr][tokenId][i].amount
            ) {
                _removeBid(
                    auctionsBySeller[msg.sender][contractAddr][tokenId][i],
                    auctionsBySeller[msg.sender][contractAddr][tokenId][i]
                        .bidders[j],
                    auctionsBySeller[msg.sender][contractAddr][tokenId][i]
                        .bidAmounts[j] -
                        auctionsBySeller[msg.sender][contractAddr][tokenId][i]
                            .amount
                );
            }
        }
        if (
            auctionsBySeller[msg.sender][contractAddr][tokenId][i].amount == 0
        ) {
            removeAt(auctionsBySeller[msg.sender][contractAddr][tokenId], i);
            if (
                auctionsBySeller[msg.sender][contractAddr][tokenId].length == 0
            ) {
                ArrayLibrary.removeAt(
                    auctionTokenIdsBySeller[msg.sender][contractAddr],
                    ArrayLibrary.findIndex(
                        auctionTokenIdsBySeller[msg.sender][contractAddr],
                        tokenId
                    )
                );
            }
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function getSalesByNFT(address contractAddr, uint256 tokenId)
        external
        view
        isProperContract(contractAddr)
        returns (Sale[] memory sales, uint256[] memory currentPrices)
    {
        uint256 length = tokenIdToSales[contractAddr][tokenId].length;
        uint256 i;
        sales = new Sale[](length);
        currentPrices = new uint256[](length);
        for (i = 0; i < length; ++i) {
            sales[i] = tokenIdToSales[contractAddr][tokenId][i];
            currentPrices[i] = getCurrentPrice(
                contractAddr,
                tokenId,
                _getSaleInfo(sales[i])
            );
        }
    }

    function getSalesBySellerNFT(
        address seller,
        address contractAddr,
        uint256 tokenId
    )
        external
        view
        isProperContract(contractAddr)
        returns (Sale[] memory sales, uint256[] memory currentPrices)
    {
        uint256 length = salesBySeller[seller][contractAddr][tokenId].length;
        uint256 i;
        sales = new Sale[](length);
        currentPrices = new uint256[](length);
        for (i = 0; i < length; ++i) {
            sales[i] = salesBySeller[seller][contractAddr][tokenId][i];
            currentPrices[i] = getCurrentPrice(
                contractAddr,
                tokenId,
                _getSaleInfo(sales[i])
            );
        }
    }

    function getSale(
        address contractAddr,
        uint256 tokenId,
        address seller,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 startedAt,
        uint256 duration,
        uint256 amount
    )
        external
        view
        isProperContract(contractAddr)
        returns (Sale memory sale, uint256 currentPrice)
    {
        return
            _getSale(
                contractAddr,
                tokenId,
                SaleInfo(
                    seller,
                    payment,
                    startPrice,
                    endPrice,
                    amount,
                    startedAt,
                    duration
                )
            );
    }

    function _getSale(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sl
    ) internal view returns (Sale memory sale, uint256 currentPrice) {
        uint256 i = _findSaleIndex(tokenIdToSales[contractAddr][tokenId], sl);
        sale = tokenIdToSales[contractAddr][tokenId][i];
        require(
            i < tokenIdToSales[contractAddr][tokenId].length,
            "Not On Sale"
        );
        currentPrice = getCurrentPrice(contractAddr, tokenId, sl);
    }

    function getSales(address contractAddr)
        external
        view
        isProperContract(contractAddr)
        returns (Sale[] memory sales, uint256[] memory currentPrices)
    {
        uint256 i;
        uint256 j;
        uint256 length = 0;
        for (i = 0; i < saleTokenIds[contractAddr].length; ++i) {
            length += tokenIdToSales[contractAddr][
                saleTokenIds[contractAddr][i]
            ].length;
        }
        if (length > 0) {
            sales = new Sale[](length);
            currentPrices = new uint256[](length);
            length = 0;
            for (i = 0; i < saleTokenIds[contractAddr].length; ++i) {
                for (
                    j = 0;
                    j <
                    tokenIdToSales[contractAddr][saleTokenIds[contractAddr][i]]
                        .length;
                    ++j
                ) {
                    sales[length] = tokenIdToSales[contractAddr][
                        saleTokenIds[contractAddr][i]
                    ][j];
                    currentPrices[length] = getCurrentPrice(
                        contractAddr,
                        saleTokenIds[contractAddr][i],
                        _getSaleInfo(sales[length])
                    );
                    ++length;
                }
            }
        }
    }

    function getSalesBySeller(address contractAddr, address owner)
        external
        view
        isProperContract(contractAddr)
        returns (Sale[] memory sales, uint256[] memory currentPrices)
    {
        uint256 i;
        uint256 j;
        uint256 length = 0;
        for (i = 0; i < saleTokenIdsBySeller[owner][contractAddr].length; ++i) {
            length += salesBySeller[owner][contractAddr][
                saleTokenIdsBySeller[owner][contractAddr][i]
            ].length;
        }
        if (length > 0) {
            sales = new Sale[](length);
            currentPrices = new uint256[](length);
            length = 0;
            for (
                i = 0;
                i < saleTokenIdsBySeller[owner][contractAddr].length;
                ++i
            ) {
                for (
                    j = 0;
                    j <
                    salesBySeller[owner][contractAddr][
                        saleTokenIdsBySeller[owner][contractAddr][i]
                    ].length;
                    ++j
                ) {
                    sales[length] = salesBySeller[owner][contractAddr][
                        saleTokenIdsBySeller[owner][contractAddr][i]
                    ][j];
                    currentPrices[length] = getCurrentPrice(
                        contractAddr,
                        saleTokenIdsBySeller[owner][contractAddr][i],
                        _getSaleInfo(sales[length])
                    );
                    ++length;
                }
            }
        }
    }

    function getAuctions(address contractAddr)
        external
        view
        isProperContract(contractAddr)
        returns (Auction[] memory)
    {
        uint256 length = 0;
        uint256 i;
        uint256 j;
        Auction[] memory auctions;
        for (i = 0; i < auctionTokenIds[contractAddr].length; ++i) {
            length += tokenIdToAuctions[contractAddr][
                auctionTokenIds[contractAddr][i]
            ].length;
        }
        if (length > 0) {
            auctions = new Auction[](length);
            length = 0;
            for (i = 0; i < auctionTokenIds[contractAddr].length; ++i) {
                for (
                    j = 0;
                    j <
                    tokenIdToAuctions[contractAddr][
                        auctionTokenIds[contractAddr][i]
                    ].length;
                    ++j
                ) {
                    auctions[length++] = tokenIdToAuctions[contractAddr][
                        auctionTokenIds[contractAddr][i]
                    ][j];
                }
            }
        }
        return auctions;
    }

    function getAuctionsBySeller(address contractAddr, address owner)
        external
        view
        isProperContract(contractAddr)
        returns (Auction[] memory)
    {
        uint256 length = 0;
        uint256 i;
        uint256 j;
        Auction[] memory auctions;
        for (
            i = 0;
            i < auctionTokenIdsBySeller[owner][contractAddr].length;
            ++i
        ) {
            length += auctionsBySeller[owner][contractAddr][
                auctionTokenIdsBySeller[owner][contractAddr][i]
            ].length;
        }
        if (length > 0) {
            auctions = new Auction[](length);
            length = 0;
            for (
                i = 0;
                i < auctionTokenIdsBySeller[owner][contractAddr].length;
                ++i
            ) {
                for (
                    j = 0;
                    j <
                    auctionsBySeller[owner][contractAddr][
                        auctionTokenIdsBySeller[owner][contractAddr][i]
                    ].length;
                    ++j
                ) {
                    auctions[length++] = auctionsBySeller[owner][contractAddr][
                        auctionTokenIdsBySeller[owner][contractAddr][i]
                    ][j];
                }
            }
        }
        return auctions;
    }

    function getAuctionsByNFT(address contractAddr, uint256 tokenId)
        external
        view
        isProperContract(contractAddr)
        returns (Auction[] memory)
    {
        return tokenIdToAuctions[contractAddr][tokenId];
    }

    function getAuctionsBySellerNFT(
        address seller,
        address contractAddr,
        uint256 tokenId
    ) external view isProperContract(contractAddr) returns (Auction[] memory) {
        return auctionsBySeller[seller][contractAddr][tokenId];
    }

    function getCurrentPrice(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sale
    )
        public
        view
        isProperContract(contractAddr)
        onSale(contractAddr, tokenId, sale)
        returns (uint256)
    {
        if (block.timestamp >= sale.startedAt + sale.duration) {
            return sale.endPrice;
        }
        return (sale.startPrice -
            ((sale.startPrice - sale.endPrice) *
                (block.timestamp - sale.startedAt)) /
            sale.duration);
    }
}
