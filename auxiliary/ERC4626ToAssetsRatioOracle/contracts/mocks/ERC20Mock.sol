// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {ERC20} from "./ERC4626/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("ERC20Mock", "E20M") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
