// SPDX-License-Identifier:MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.22;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizeStablecoin is ERC20Burnable, Ownable {
    /*
    * @title DecentralizedStableCoin
    * @author NithinKumar
    * Collateral: Exogenous like BTC,ETH
    * Minting (Stability Mechanism): Decentralized (Algorithmic)
    * Value (Relative Stability): Anchored (Pegged to USD)
    * Collateral Type: Crypto
    *
    * This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the
    DSCEngine smart contract.
    */
    /*errors*/
    error _MustbeLessThanZero();
    error Not_BurnAmountExceedmorethanBalance();
    error _MustEnterCorrectAddr();

    constructor(
        address intialOwner
    ) ERC20("DecentraliseStablecoin", "DSC") Ownable(intialOwner) {}

    function burn(uint256 _amount) public override onlyOwner {
        if (_amount <= 0) {
            revert _MustbeLessThanZero();
        }
        uint256 balance = balanceOf(msg.sender);
        if (balance < _amount) {
            revert Not_BurnAmountExceedmorethanBalance();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert _MustEnterCorrectAddr();
        }
        if (_amount < 0) {
            revert _MustbeLessThanZero();
        }
        _mint(msg.sender, _amount);
        return true;
    }
}
