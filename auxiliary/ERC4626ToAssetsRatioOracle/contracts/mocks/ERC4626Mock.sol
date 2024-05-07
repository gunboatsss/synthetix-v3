// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {ERC20, IERC20} from "@synthetixio/core-contracts/contracts/token/ERC20.sol";
import {ERC4626} from "./ERC4626.sol";

contract ERC4626Mock is ERC4626 {
    constructor(address underlying) ERC20("ERC4626Mock", "E4626M") ERC4626(IERC20(underlying)) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
