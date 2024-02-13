// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/access/Ownable.sol";

import "./interfaces/IRandomOracle.sol";

contract MockRandomOracle is IRandomOracle, Ownable {
    mapping(uint256 => uint256) private _randomNumbers;

    constructor(address owner_) Ownable(owner_) {}

    function setRandomNumber(uint256 id, uint256 number) external onlyOwner {
        // @dev We should check id is current round at the production environment.
        _randomNumbers[id] = number;
    }

    function getRandomNumber(uint256 id) external view returns (uint256) {
        // @dev We should check if tha value is initialized at the production environment.
        return _randomNumbers[id];
    }
}
