// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol";

contract Contract is ERC20, ERC20Burnable, Ownable {
    constructor(string memory name, string memory symbol, uint8 decimal, uint256 initialSupply) ERC20(name, symbol, decimal) {
        uint256 amount = initialSupply * 10 ** decimal;
        _mint(msg.sender, amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount * 10 ** decimals());
    }
}