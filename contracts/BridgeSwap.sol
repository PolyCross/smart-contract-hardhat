// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./interfaces/IBridgeSwap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

struct Pool {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
}

contract BridgeSwap is IBridgeSwap, ERC1155Supply, ReentrancyGuard {
    constructor() ERC1155("") {}

    Pool[] poolList;
    mapping(address => mapping(address => bool)) public isPoolExists;
    mapping(address => mapping(address => uint)) poolIndex;

    // ===================================================== Read Functions =====================================================

    /**
     * @dev show the total amount of pools
     * @return totalAmount the total amount of pools
     */
    function poolTotalAmount() public view returns (uint256 totalAmount) {
        totalAmount = poolList.length;
    }

    /**
     * @dev get the reserve of pool
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @return token0 token0 address
     * @return token1 token1 address
     * @return amount0 token0 amount
     * @return amount1 token1 amount
     */
    function getPoolInfo(
        address tokenA,
        address tokenB
    )
        public
        view
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        if (!isPoolExists[tokenA][tokenB]) revert("Pool doesn't exist");
        uint256 index = poolIndex[tokenA][tokenB];
        Pool memory targetPool = poolList[index];
        (token0, token1, amount0, amount1) = (
            targetPool.token0,
            targetPool.token1,
            targetPool.amount0,
            targetPool.amount1
        );
    }

    // ===================================================== Write Functions =====================================================

    /**
     * @dev init liquidity pool
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @param amountA tokenA amount
     * @param amountB tokenB amount
     */
    function initPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to
    ) public nonReentrant returns (uint256 share) {
        if (tokenA == tokenB) revert SameToken();
        if (isPoolExists[tokenA][tokenB]) revert PoolExists();

        poolIndex[tokenA][tokenB] = poolList.length;
        poolIndex[tokenB][tokenA] = poolList.length;

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        if (tokenA < tokenB) {
            Pool memory newPool = Pool({
                token0: tokenA,
                token1: tokenB,
                amount0: amountA,
                amount1: amountB
            });
            poolList.push(newPool);
        } else {
            Pool memory newPool = Pool({
                token0: tokenB,
                token1: tokenA,
                amount0: amountB,
                amount1: amountA
            });
            poolList.push(newPool);
        }

        isPoolExists[tokenA][tokenB] = true;
        isPoolExists[tokenB][tokenA] = true;

        share = Math.sqrt(amountA * amountB);

        mint(to, poolList.length - 1, share, "init pool");
    }

    /**
     * @dev add liquidity
     * @param tokenA tokenA address
     * @param tokenB tokenB address
     * @param amountA tokenA amount
     * @param amountB tokenB amount
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to
    ) public nonReentrant returns (uint256 share) {
        if (tokenA == tokenB) revert SameToken();
        if (!isPoolExists[tokenA][tokenB]) {
            share = initPool(tokenA, tokenB, amountA, amountB, to);
        } else {
            uint256 index = poolIndex[tokenA][tokenB];

            IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
            IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

            Pool storage targetPool = poolList[index];
            uint256 _totalSupply = totalSupply(index);

            if (tokenA < tokenB) {
                share = Math.min(
                    (amountA * _totalSupply) / targetPool.amount0,
                    (amountB * _totalSupply) / targetPool.amount1
                );
                targetPool.amount0 += amountA;
                targetPool.amount1 += amountB;
            } else {
                share = Math.min(
                    (amountB * _totalSupply) / targetPool.amount0,
                    (amountA * _totalSupply) / targetPool.amount1
                );
                targetPool.amount0 += amountB;
                targetPool.amount1 += amountA;
            }

            mint(to, index, share, "add liquidity");
        }
    }

    // TODO: Swap Function

    // ===================================================== ERC-1155 Functions =====================================================

    function mint(
        address to,
        uint256 index,
        uint256 amount,
        bytes memory data
    ) private {
        _mint(to, index, amount, data);
    }
}
