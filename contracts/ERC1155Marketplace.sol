// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./ERC1155MarketplaceBase.sol";

contract ERC1155Marketplace is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC1155MarketplaceBase
{
    function createSale(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration,
        uint256 amount
    ) external isProperContract(contractAddr) {
        require(startPrice >= endPrice, "Invalid Sale Prices");
        _createSale(
            CreateSaleReq(
                contractAddr,
                tokenId,
                payment,
                startPrice,
                endPrice,
                amount,
                duration
            )
        );
    }

    function _createSale(CreateSaleReq memory createSaleReq) internal {
        address[] memory offerers;
        uint256[] memory offerPrices;
        uint256[] memory offerAmounts;
        IERC1155(createSaleReq.contractAddr).safeTransferFrom(
            msg.sender,
            address(this),
            createSaleReq.tokenId,
            createSaleReq.amount,
            ""
        );
        uint256 timestamp = block.timestamp;
        _addSale(
            createSaleReq.contractAddr,
            createSaleReq.tokenId,
            Sale(
                createSaleReq.payment,
                msg.sender,
                createSaleReq.startPrice,
                createSaleReq.endPrice,
                createSaleReq.amount,
                timestamp,
                createSaleReq.duration,
                offerers,
                offerPrices,
                offerAmounts
            )
        );
        emit SaleCreated(
            createSaleReq.contractAddr,
            createSaleReq.tokenId,
            createSaleReq.startPrice,
            createSaleReq.endPrice,
            createSaleReq.amount,
            timestamp,
            createSaleReq.duration
        );
    }

    function buy(
        address contractAddr,
        uint256 tokenId,
        address seller,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 amount,
        uint256 startedAt,
        uint256 duration
    ) external payable isProperContract(contractAddr) nonReentrant {
        _buy(
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

    function _buy(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sale
    ) internal onSale(contractAddr, tokenId, sale) {
        require(msg.sender != sale.seller, "Caller Is Seller");
        uint256 price = getCurrentPrice(contractAddr, tokenId, sale) *
            sale.amount;
        _escrowFund(sale.payment, price);
        _transferFund(sale.payment, price, sale.seller);
        IERC1155(contractAddr).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            sale.amount,
            ""
        );
        _removeSale(contractAddr, tokenId, sale);
        emit SaleSuccessful(contractAddr, tokenId, sale, price, msg.sender);
    }

    function cancelSale(
        address contractAddr,
        uint256 tokenId,
        address seller,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 amount,
        uint256 startedAt,
        uint256 duration
    ) external isProperContract(contractAddr) {
        _cancelSale(
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

    function _cancelSale(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sale
    ) internal onSale(contractAddr, tokenId, sale) {
        require(msg.sender == sale.seller, "Caller Is Not Seller");
        IERC1155(contractAddr).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            sale.amount,
            ""
        );
        _removeSale(contractAddr, tokenId, sale);
        emit SaleCancelled(contractAddr, tokenId, sale);
    }

    function makeOffer(
        address contractAddr,
        uint256 tokenId,
        address seller,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 startedAt,
        uint256 duration,
        uint256 price,
        uint256 amount
    ) external payable isProperContract(contractAddr) {
        _makeOffer(
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
            ),
            price,
            amount
        );
    }

    function _makeOffer(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sale,
        uint256 price,
        uint256 amount
    ) internal {
        require(msg.sender != sale.seller, "Caller Is Not Buyer"); //onlyBuyer Modifier
        uint256 curPrice = getCurrentPrice(contractAddr, tokenId, sale);
        _escrowFund(sale.payment, price * amount);
        _createOffer(
            tokenIdToSales[contractAddr][tokenId],
            sale,
            price,
            amount,
            curPrice
        );
        _createOffer(
            salesBySeller[sale.seller][contractAddr][tokenId],
            sale,
            price,
            amount,
            curPrice
        );
        uint256 i = _findSaleIndex(tokenIdToSales[contractAddr][tokenId], sale);
        emit OfferCreated(
            tokenIdToSales[contractAddr][tokenId][i],
            contractAddr,
            tokenId,
            price,
            amount,
            msg.sender
        );
    }

    function cancelOffer(
        address seller,
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 startedAt,
        uint256 duration,
        uint256 amount
    ) external isProperContract(contractAddr) {
        _cancelOffer(
            SaleInfo(
                seller,
                payment,
                startPrice,
                endPrice,
                amount,
                startedAt,
                duration
            ),
            contractAddr,
            tokenId,
            amount
        );
    }

    function _cancelOffer(
        SaleInfo memory sale,
        address contractAddr,
        uint256 tokenId,
        uint256 amount
    ) internal {
        require(msg.sender != sale.seller, "Caller Is Not Buyer"); //onlyBuyer Modifier
        uint256 i = _findSaleIndex(tokenIdToSales[contractAddr][tokenId], sale);
        _transferFund(
            tokenIdToSales[contractAddr][tokenId][i].payment,
            tokenIdToSales[contractAddr][tokenId][i].offerPrices[
                ArrayLibrary.findIndex(
                    tokenIdToSales[contractAddr][tokenId][i].offerers,
                    msg.sender
                )
            ] * amount,
            msg.sender
        );
        _removeOffer(
            tokenIdToSales[contractAddr][tokenId],
            sale,
            amount,
            msg.sender
        );
        _removeOffer(
            salesBySeller[sale.seller][contractAddr][tokenId],
            sale,
            amount,
            msg.sender
        );
        emit OfferCancelled(
            tokenIdToSales[contractAddr][tokenId][i],
            contractAddr,
            tokenId,
            amount,
            msg.sender
        );
    }

    function acceptOffer(
        address seller,
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 startedAt,
        uint256 duration,
        uint256 amount
    ) external isProperContract(contractAddr) {
        _acceptOffer(
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
            ),
            amount
        );
    }

    function _acceptOffer(
        address contractAddr,
        uint256 tokenId,
        SaleInfo memory sale,
        uint256 amount
    ) internal isProperContract(contractAddr) {
        require(msg.sender == sale.seller, "Caller Is Not Seller"); //onlySeller Modifier
        //Finding sale of the NFT
        uint256 i = _findSaleIndex(tokenIdToSales[contractAddr][tokenId], sale);
        require(
            i < tokenIdToSales[contractAddr][tokenId].length,
            "Not On Sale"
        );
        Sale memory curSale = tokenIdToSales[contractAddr][tokenId][i];
        require(curSale.amount >= amount, "Insufficient Sale For Offer");
        require(curSale.offerers.length > 0, "No Offer on the Sale");
        uint256 maxOffererId = ArrayLibrary.findMaxIndex(curSale.offerPrices);
        require(
            curSale.offerAmounts[maxOffererId] >= amount,
            "Insufficient Offer To Accept"
        );
        uint256 price = curSale.offerPrices[maxOffererId] * amount;
        _transferFund(sale.payment, price, msg.sender);
        IERC1155(contractAddr).safeTransferFrom(
            address(this),
            curSale.offerers[maxOffererId],
            tokenId,
            amount,
            ""
        );
        address buyer = curSale.offerers[maxOffererId];
        _removeOffer(
            tokenIdToSales[contractAddr][tokenId],
            sale,
            amount,
            buyer
        );
        _removeOffer(
            salesBySeller[msg.sender][contractAddr][tokenId],
            sale,
            amount,
            buyer
        );
        _removeSale(contractAddr, tokenId, sale);
        emit SaleSuccessful(contractAddr, tokenId, sale, price, buyer);
    }

    function createAuction(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 amount
    ) external isProperContract(contractAddr) {
        IERC1155(contractAddr).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );
        address[] memory bidders;
        uint256[] memory bidPrices;
        uint256[] memory bidAmounts;
        Auction memory auction = Auction(
            payment,
            msg.sender,
            amount,
            block.timestamp,
            bidders,
            bidPrices,
            bidAmounts
        );
        if (tokenIdToAuctions[contractAddr][tokenId].length == 0) {
            auctionTokenIds[contractAddr].push(tokenId);
        }
        tokenIdToAuctions[contractAddr][tokenId].push(auction);
        if (auctionsBySeller[msg.sender][contractAddr][tokenId].length == 0) {
            auctionTokenIdsBySeller[msg.sender][contractAddr].push(tokenId);
        }
        auctionsBySeller[msg.sender][contractAddr][tokenId].push(auction);
        emit AuctionCreated(contractAddr, tokenId, payment, amount);
    }

    function cancelAuction(
        address contractAddr,
        uint256 tokenId,
        uint256 startedAt,
        uint256 amount
    ) external onAuction(msg.sender, contractAddr, tokenId, startedAt, amount) {
        IERC1155(contractAddr).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );
        _cancelAuction(contractAddr, tokenId, startedAt, amount);
        emit AuctionCancelled(contractAddr, tokenId, startedAt, amount);
    }

    function bid(
        address contractAddr,
        uint256 tokenId,
        address auctioneer,
        uint256 startedAt,
        uint256 bidAmount,
        uint256 bidPrice
    )
        external
        payable
        onAuction(auctioneer, contractAddr, tokenId, startedAt, bidAmount)
    {
        require(msg.sender != auctioneer, "Auctioneer Cannot Bid");
        _bid(
            BidReq(contractAddr, tokenId, auctioneer, startedAt, bidAmount),
            bidPrice
        );
        emit AuctionBid(
            contractAddr,
            tokenId,
            auctioneer,
            startedAt,
            bidPrice,
            bidAmount
        );
    }

    function _bid(BidReq memory req, uint256 bidPrice) internal {
        uint256 i = _findAuctionIndex(
            tokenIdToAuctions[req.contractAddr][req.tokenId],
            req.auctioneer,
            req.startedAt
        );
        _escrowFund(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].payment,
            bidPrice * req.bidAmount
        );
        _bidAuction(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i],
            bidPrice,
            req.bidAmount
        );
        i = _findAuctionIndex(
            auctionsBySeller[req.auctioneer][req.contractAddr][req.tokenId],
            req.auctioneer,
            req.startedAt
        );
        _bidAuction(
            auctionsBySeller[req.auctioneer][req.contractAddr][req.tokenId][i],
            bidPrice,
            req.bidAmount
        );
    }

    function cancelBid(
        address contractAddr,
        uint256 tokenId,
        address auctioneer,
        uint256 startedAt,
        uint256 bidAmount
    )
        external
        onAuction(auctioneer, contractAddr, tokenId, startedAt, bidAmount)
    {
        _cancelBid(
            BidReq(contractAddr, tokenId, auctioneer, startedAt, bidAmount)
        );
        emit CancelBid(contractAddr, tokenId, auctioneer, startedAt, bidAmount);
    }

    function _cancelBid(BidReq memory req) internal {
        uint256 i = _findAuctionIndex(
            tokenIdToAuctions[req.contractAddr][req.tokenId],
            req.auctioneer,
            req.startedAt
        );
        uint256 j = ArrayLibrary.findIndex(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].bidders,
            msg.sender
        );
        _transferFund(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].payment,
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].bidPrices[j] *
                req.bidAmount,
            msg.sender
        );
        _removeBid(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i],
            msg.sender,
            req.bidAmount
        );
        i = _findAuctionIndex(
            auctionsBySeller[req.auctioneer][req.contractAddr][req.tokenId],
            req.auctioneer,
            req.startedAt
        );
        _removeBid(
            auctionsBySeller[req.auctioneer][req.contractAddr][req.tokenId][i],
            msg.sender,
            req.bidAmount
        );
    }

    function acceptBid(
        address contractAddr,
        uint256 tokenId,
        uint256 startedAt,
        uint256 bidAmount
    )
        external
        payable
        onAuction(msg.sender, contractAddr, tokenId, startedAt, bidAmount)
    {
        _acceptBid(
            BidReq(contractAddr, tokenId, msg.sender, startedAt, bidAmount)
        );
        emit BidAccepted(contractAddr, tokenId, startedAt, bidAmount);
    }

    function _acceptBid(BidReq memory req) internal {
        uint256 i = _findAuctionIndex(
            tokenIdToAuctions[req.contractAddr][req.tokenId],
            msg.sender,
            req.startedAt
        );
        require(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].bidders.length >
                0,
            "No Offer to Accept"
        );
        uint256 j = ArrayLibrary.findMaxIndex(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].bidPrices
        );
        require(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].bidAmounts[j] >=
                req.bidAmount,
            "Insuffcient Bid to Accept"
        );
        address buyer = tokenIdToAuctions[req.contractAddr][req.tokenId][i]
            .bidders[j];
        IERC1155(req.contractAddr).safeTransferFrom(
            address(this),
            buyer,
            req.tokenId,
            req.bidAmount,
            ""
        );
        _transferFund(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].payment,
            tokenIdToAuctions[req.contractAddr][req.tokenId][i].bidPrices[j] *
                req.bidAmount,
            msg.sender
        );
        _removeBid(
            tokenIdToAuctions[req.contractAddr][req.tokenId][i],
            buyer,
            req.bidAmount
        );
        i = _findAuctionIndex(
            auctionsBySeller[msg.sender][req.contractAddr][req.tokenId],
            msg.sender,
            req.startedAt
        );
        _removeBid(
            auctionsBySeller[msg.sender][req.contractAddr][req.tokenId][i],
            buyer,
            req.bidAmount
        );
        _cancelAuction(
            req.contractAddr,
            req.tokenId,
            req.startedAt,
            req.bidAmount
        );
    }
}
