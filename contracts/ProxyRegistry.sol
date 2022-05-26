// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

contract ProxyRegistry {
    mapping(address => address) public proxies;

    function setProxy(address addr) external {
        proxies[msg.sender] = addr;
    }
}
