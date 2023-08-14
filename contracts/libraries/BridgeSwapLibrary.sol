// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

library BridgeSwapLibrary {
    error InsufficientInputAmount();
    error InsufficientLiquidity();

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientInputAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}
