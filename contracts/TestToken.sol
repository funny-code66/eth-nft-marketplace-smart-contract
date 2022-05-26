// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TKN", "TKN") {}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
