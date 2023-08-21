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

    function sortTokenWithAmount(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    )
        internal
        pure
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        if(tokenA < tokenB) {
            (token0, token1, amount0, amount1) = (tokenA, tokenB, amountA, amountB);
        } else {
            (token0, token1, amount0, amount1) = (tokenB, tokenA, amountB, amountA);
        }
    }
}
