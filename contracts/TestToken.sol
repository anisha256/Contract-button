//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TestToken is ERC20, ERC20Burnable, AccessControl {
    constructor(address _admin) ERC20("TestToken", "TT") {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}
