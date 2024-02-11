// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockToken is ERC20Permit, Ownable {
    uint8 private immutable _decimals;

    constructor(address owner_, string memory name, string memory symbol, uint8 decimals_)
        ERC20(name, symbol)
        ERC20Permit(name)
        Ownable(owner_)
    {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
