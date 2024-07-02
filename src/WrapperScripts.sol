// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IWstETH} from "./interfaces/IWstETH.sol";

contract IWETHActions {
    function wrapETH(address wrapper, uint256 amount) external payable {
        IWETH(wrapper).deposit{value: amount}();
    }

    function unwrapWETH(address wrapper, uint256 amount) external {
        IWETH(wrapper).withdraw(amount);
    }
}

contract IWstETHActions {
    function wrapLidoStETH(address wrapper, address tokenToWrap, uint256 amount) external {
        IERC20(tokenToWrap).approve(wrapper, amount);
        IWstETH(wrapper).wrap(amount);
    }

    function unwrapLidoWstETH(address wrapper, address tokenToUnwrap, uint256 amount) external {
        IERC20(tokenToUnwrap).approve(wrapper, amount);
        IWstETH(wrapper).unwrap(amount);
    }
}
