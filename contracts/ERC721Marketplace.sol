// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./ERC721MarketplaceBase.sol";

contract ERC721Marketplace is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721MarketplaceBase
{
    function createSale(
        address contractAddr,
        uint256 tokenId,
        uint256 payment,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration
    )
        external
        virtual
        isProperContract(contractAddr)
        whenNotPaused
        owningToken(contractAddr, tokenId)
    {
        IERC721(contractAddr).transferFrom(msg.sender, address(this), tokenId);
        tokenIdToSales[contractAddr][tokenId] = Sale(
            msg.sender,
            payment,
            startPrice,
            endPrice,
            block.timestamp,
            duration
        );
        saleTokenIds[contractAddr].push(tokenId);
        saleTokenIdsBySeller[msg.sender][contractAddr].push(tokenId);

        emit SaleCreated(
            contractAddr,
            tokenId,
            payment,
            startPrice,
            endPrice,
            block.timestamp,
            duration
        );
    }

    function buy(address contractAddr, uint256 tokenId)
        external
        payable
        virtual
        isProperContract(contractAddr)
        whenNotPaused
        onSale(contractAddr, tokenId)
        onlyBuyer(contractAddr, tokenId)
        nonReentrant
    {
        Sale storage sale = tokenIdToSales[contractAddr][tokenId];
        uint256 price = getCurrentPrice(contractAddr, tokenId);
        _escrowFund(sale.payment, price);
        _transferFund(sale.payment, price, sale.seller);
        _removeSale(contractAddr, tokenId);
        IERC721(contractAddr).transferFrom(address(this), msg.sender, tokenId);
        emit SaleSuccessful(
            contractAddr,
            tokenId,
            sale.payment,
            price,
            msg.sender
        );
    }

    function cancelSale(address contractAddr, uint256 tokenId)
        external
        isProperContract(contractAddr)
        onSale(contractAddr, tokenId)
        onlySeller(contractAddr, tokenId)
    {
        IERC721(contractAddr).transferFrom(
            address(this),
            tokenIdToSales[contractAddr][tokenId].seller,
            tokenId
        );
        _removeSale(contractAddr, tokenId);
        emit SaleCancelled(contractAddr, tokenId);
    }

    function cancelSaleWhenPaused(address contractAddr, uint256 tokenId)
        external
        isProperContract(contractAddr)
        whenPaused
        onlyOwner
        onSale(contractAddr, tokenId)
    {
        IERC721(contractAddr).transferFrom(
            address(this),
            tokenIdToSales[contractAddr][tokenId].seller,
            tokenId
        );
        _removeSale(contractAddr, tokenId);
        emit SaleCancelled(contractAddr, tokenId);
    }

    function makeOffer(
        address contractAddr,
        uint256 tokenId,
        uint256 price
    )
        external
        payable
        isProperContract(contractAddr)
        onSale(contractAddr, tokenId)
        onlyBuyer(contractAddr, tokenId)
    {
        _escrowFund(tokenIdToSales[contractAddr][tokenId].payment, price);
        tokenIdToOffers[contractAddr][tokenId].push(Offer(msg.sender, price));
        emit OfferCreated(contractAddr, tokenId, msg.value, msg.sender);
    }

    function cancelOffer(address contractAddr, uint256 tokenId)
        external
        isProperContract(contractAddr)
        onSale(contractAddr, tokenId)
        onlyBuyer(contractAddr, tokenId)
    {
        uint256 i;
        uint256 length = tokenIdToOffers[contractAddr][tokenId].length;
        for (
            i = 0;
            i < length &&
                tokenIdToOffers[contractAddr][tokenId][i].offerer != msg.sender;
            ++i
        ) {}
        require(i < length, "You Have No Offer");
        uint256 price = tokenIdToOffers[contractAddr][tokenId][i].offerPrice;
        _transferFund(
            tokenIdToSales[contractAddr][tokenId].payment,
            price,
            msg.sender
        );
        removeAt(tokenIdToOffers[contractAddr][tokenId], i);
        emit OfferCancelled(contractAddr, tokenId, price, msg.sender);
    }

    function acceptOffer(address contractAddr, uint256 tokenId)
        external
        isProperContract(contractAddr)
        onSale(contractAddr, tokenId)
        onlySeller(contractAddr, tokenId)
    {
        uint256 i;
        uint256 maxOffererId = 0;
        uint256 length = tokenIdToOffers[contractAddr][tokenId].length;
        uint256 payment = tokenIdToSales[contractAddr][tokenId].payment;
        require(length > 0, "No Offer on the Sale");
        for (i = 1; i < length; ++i) {
            if (
                tokenIdToOffers[contractAddr][tokenId][i].offerPrice >
                tokenIdToOffers[contractAddr][tokenId][maxOffererId].offerPrice
            ) {
                maxOffererId = i;
            }
        }
        Offer memory curOffer = tokenIdToOffers[contractAddr][tokenId][
            maxOffererId
        ];
        _transferFund(payment, curOffer.offerPrice, msg.sender);
        IERC721(contractAddr).transferFrom(
            address(this),
            curOffer.offerer,
            tokenId
        );
        removeAt(tokenIdToOffers[contractAddr][tokenId], maxOffererId);
        _removeSale(contractAddr, tokenId);
        emit OfferAccepted(
            contractAddr,
            tokenId,
            payment,
            curOffer.offerPrice,
            curOffer.offerer
        );
    }

    function createAuction(
        address contractAddr,
        uint256 tokenId,
        uint256 payment
    )
        external
        isProperContract(contractAddr)
        whenNotPaused
        owningToken(contractAddr, tokenId)
    {
        IERC721(contractAddr).transferFrom(msg.sender, address(this), tokenId);
        address[] memory bidders;
        uint256[] memory bidPrices;
        tokenIdToAuctions[contractAddr][tokenId] = Auction(
            payment,
            msg.sender,
            bidders,
            bidPrices
        );
        auctionTokenIds[contractAddr].push(tokenId);
        auctionTokenIdsBySeller[msg.sender][contractAddr].push(tokenId);

        emit AuctionCreated(contractAddr, tokenId, payment, msg.sender);
    }

    function bid(address contractAddr, uint256 tokenId)
        external
        payable
        isProperContract(contractAddr)
        whenNotPaused
        onAuction(contractAddr, tokenId)
    {
        uint256 i = ArrayLibrary.findIndex(
            tokenIdToAuctions[contractAddr][tokenId].bidders,
            msg.sender
        );
        require(
            i == tokenIdToAuctions[contractAddr][tokenId].bidders.length,
            "Already Has Bid"
        );
        tokenIdToAuctions[contractAddr][tokenId].bidders.push(msg.sender);
        tokenIdToAuctions[contractAddr][tokenId].bidPrices.push(msg.value);
        emit AuctionBid(contractAddr, tokenId, msg.sender, msg.value);
    }

    function cancelBid(address contractAddr, uint256 tokenId)
        external
        isProperContract(contractAddr)
        whenNotPaused
        onAuction(contractAddr, tokenId)
    {
        uint256 i = ArrayLibrary.findIndex(
            tokenIdToAuctions[contractAddr][tokenId].bidders,
            msg.sender
        );
        require(
            i < tokenIdToAuctions[contractAddr][tokenId].bidders.length,
            "Has No Bid"
        );
        _transferFund(
            tokenIdToAuctions[contractAddr][tokenId].payment,
            tokenIdToAuctions[contractAddr][tokenId].bidPrices[i],
            tokenIdToAuctions[contractAddr][tokenId].bidders[i]
        );
        ArrayLibrary.removeAt(
            tokenIdToAuctions[contractAddr][tokenId].bidders,
            i
        );
        ArrayLibrary.removeAt(
            tokenIdToAuctions[contractAddr][tokenId].bidPrices,
            i
        );
        emit CancelBid(contractAddr, tokenId, msg.sender);
    }

    function cancelAuction(address contractAddr, uint256 tokenId)
        external
        payable
        isProperContract(contractAddr)
        whenNotPaused
        onAuction(contractAddr, tokenId)
    {
        IERC721(contractAddr).transferFrom(address(this), msg.sender, tokenId);
        _cancelAuction(contractAddr, tokenId);
        emit AuctionCancelled(contractAddr, tokenId, msg.sender);
    }

    function acceptBid(address contractAddr, uint256 tokenId)
        external
        isProperContract(contractAddr)
        whenNotPaused
        onAuction(contractAddr, tokenId)
    {
        uint256 length = tokenIdToAuctions[contractAddr][tokenId]
            .bidders
            .length;
        require(length > 0, "No Bids");
        uint256 maxBidderId = ArrayLibrary.findMaxIndex(
            tokenIdToAuctions[contractAddr][tokenId].bidPrices
        );
        _transferFund(
            tokenIdToAuctions[contractAddr][tokenId].payment,
            tokenIdToAuctions[contractAddr][tokenId].bidPrices[maxBidderId],
            msg.sender
        );
        IERC721(contractAddr).transferFrom(
            address(this),
            tokenIdToAuctions[contractAddr][tokenId].bidders[maxBidderId],
            tokenId
        );
        ArrayLibrary.removeAt(
            tokenIdToAuctions[contractAddr][tokenId].bidders,
            maxBidderId
        );
        ArrayLibrary.removeAt(
            tokenIdToAuctions[contractAddr][tokenId].bidPrices,
            maxBidderId
        );
        _cancelAuction(contractAddr, tokenId);
    }
}
