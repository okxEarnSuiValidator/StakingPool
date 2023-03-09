// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";



abstract contract IERC20AccessControl is ERC20, AccessControl{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");


    function mint(address account, uint256 amount) public virtual onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function burn(address from, uint256 amount) public virtual onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }
}