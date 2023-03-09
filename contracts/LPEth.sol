// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/IERC20AccessControl.sol";



contract LPEth is IERC20AccessControl {

    // stakingPool合约拥有LPEth的铸造权和燃烧权
    constructor(address stakingPool) ERC20("LPETH", "LPETH") {
        _grantRole(MINTER_ROLE, stakingPool);
        _grantRole(BURNER_ROLE, stakingPool);
    }

}