// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IBridgeSwap {
    // ===================================================== Errors =====================================================

    error SameToken();
    error PoolExists();
    error InvalidPath();
    error InvalidSlippage();

    // ===================================================== Events =====================================================

    event BridgeSwapIn(
        address[] path,
        uint256 amountIn,
        address indexed receiver
    );

    event BridgeSwapOut(
        address[] path,
        uint256 amountIn,
        address indexed receiver
    );

    // ===================================================== Read Functions =====================================================

    function poolTotalAmount() external view returns (uint256 totalAmount);

    function getPoolInfo(
        address tokenA,
        address tokenB
    )
        external
        view
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        );

    // ===================================================== Write Functions =====================================================

    function initPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to
    ) external returns (uint256 share);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to
    ) external returns (uint256 share);
}