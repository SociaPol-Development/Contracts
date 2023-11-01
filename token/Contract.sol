// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol";

contract Contract is ERC20, ERC20Burnable, Ownable {

	uint256 totalsupply;
	uint256 total;
    constructor(string memory name, string memory symbol, uint8 decimal, uint256 initialSupply, uint256 _totalSupply) ERC20(name, symbol, decimal) {
        uint256 amount = initialSupply * 10 ** decimal;
		totalsupply = _totalSupply * 10 ** decimal;
        _mint(msg.sender, amount);
		total += amount;
    }

    function mint(address to, uint256 amount) public onlyOwner {
		uint256 control = amount * 10 ** decimals();
		require(total + control <= totalsupply , "Total supply reached");
        _mint(to, amount * 10 ** decimals());
    }
}