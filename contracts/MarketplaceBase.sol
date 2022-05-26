// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ArrayLibrary.sol";

import "./interfaces/AddressesInterface.sol";

abstract contract MarketplaceBase is OwnableUpgradeable {
    address public addressesContractAddr;
    address public sparkTokenContractAddr;
    mapping(address => uint256[2]) internal claimable;
    mapping(address => uint256[]) internal saleTokenIds;
    mapping(address => mapping(address => uint256[]))
        internal saleTokenIdsBySeller;
    mapping(address => uint256[]) internal auctionTokenIds;
    mapping(address => mapping(address => uint256[]))
        internal auctionTokenIdsBySeller;

    modifier isProperContract(address contractAddr) {
        require(
            addressesContractAddr != address(0),
            "Addresses Contract not set"
        );
        AddressesInterface ai = AddressesInterface(addressesContractAddr);
        require(
            ai.existingContract(contractAddr) == true,
            "Not Existing Contract"
        );
        require(
            ai.isVerified(contractAddr) == true,
            "The Contract is not verified"
        );
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }

    function _escrowFund(uint256 payment, uint256 price) internal {
        if (payment == 1) {
            require(msg.value >= price, "Insufficient Fund");
        } else {
            IERC20(sparkTokenContractAddr).transferFrom(
                msg.sender,
                address(this),
                price
            );
        }
    }

    function _transferFund(
        uint256 payment,
        uint256 price,
        address destination
    ) internal {
        if (payment == 1) {
            payable(destination).transfer(price);
        } else {
            IERC20(sparkTokenContractAddr).transfer(destination, price);
        }
    }

    function setAddressesContractAddr(address contractAddr) external onlyOwner {
        addressesContractAddr = contractAddr;
    }

    function setSparkTokenContractAddr(address newSparkAddr)
        external
        onlyOwner
    {
        sparkTokenContractAddr = newSparkAddr;
    }

    function getSaleTokens(address contractAddr)
        public
        view
        isProperContract(contractAddr)
        returns (uint256[] memory)
    {
        return saleTokenIds[contractAddr];
    }

    function getSaleTokensBySeller(address contractAddr, address seller)
        public
        view
        isProperContract(contractAddr)
        returns (uint256[] memory)
    {
        return saleTokenIdsBySeller[seller][contractAddr];
    }

    function getClaimable(address user, uint256 index)
        external
        view
        returns (uint256)
    {
        return claimable[user][index - 1];
    }

    function claim(uint256 amount, uint256 index) external {
        require(
            amount <= claimable[msg.sender][index - 1],
            "Exceeds claimable amount"
        );
        claimable[msg.sender][index - 1] -= amount;
        if (index == 1) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(sparkTokenContractAddr).transfer(msg.sender, amount);
        }
    }
}
