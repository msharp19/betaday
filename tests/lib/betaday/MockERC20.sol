// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 
{
    uint8 private immutable precision;

    constructor(
        string memory name_, 
        string memory symbol_,
        uint8 _decimals
    ) ERC20(name_, symbol_) {
        precision = _decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return precision;
    }

    function mint(address to, uint256 amount) public{
        super._mint(to, amount);
    }

    function burn(address from, uint256 amount) public{
        super._burn(from, amount);
    }
}