// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./interfaces/IBridgeSwap.sol";
import "./libraries/BridgeSwapLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Pool {
    address token0;
    address token1;
    uint256 reserve0;
    uint256 reserve1;
}

contract BridgeSwap is IBridgeSwap, ERC1155Supply, ReentrancyGuard, Ownable {
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
     * @return reserve0 token0 amount
     * @return reserve1 token1 amount
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
            uint256 reserve0,
            uint256 reserve1
        )
    {
        if (!isPoolExists[tokenA][tokenB]) revert("Pool doesn't exist");
        uint256 index = poolIndex[tokenA][tokenB];
        Pool memory targetPool = poolList[index];
        (token0, token1, reserve0, reserve1) = (
            targetPool.token0,
            targetPool.token1,
            targetPool.reserve0,
            targetPool.reserve1
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
                reserve0: amountA,
                reserve1: amountB
            });
            poolList.push(newPool);
        } else {
            Pool memory newPool = Pool({
                token0: tokenB,
                token1: tokenA,
                reserve0: amountB,
                reserve1: amountA
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
                    (amountA * _totalSupply) / targetPool.reserve0,
                    (amountB * _totalSupply) / targetPool.reserve1
                );
                targetPool.reserve0 += amountA;
                targetPool.reserve1 += amountB;
            } else {
                share = Math.min(
                    (amountB * _totalSupply) / targetPool.reserve0,
                    (amountA * _totalSupply) / targetPool.reserve1
                );
                targetPool.reserve0 += amountB;
                targetPool.reserve1 += amountA;
            }

            mint(to, index, share, "add liquidity");
        }
    }

    /**
     * @dev swap exact tokens for tokens
     * @notice user op
     * @param amountIn the amount of token to swap
     * @param amountOutMin the expected minimum amount of tokens to be received
     * @param path token array
     * @return amounts the array of token out amount
     */
    function SwapIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) public returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        amounts = _swap(amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin)
            revert InvalidSlippage();

        emit BridgeSwapIn(path, amountIn, msg.sender);
    }

    /**
     * @dev swap exact tokens for tokens
     * @notice admin op
     * @param amountIn the amount of token to swap
     * @param path token array
     * @param to the receiver address
     */
    function SwapOut(
        uint256 amountIn,
        address[] calldata path,
        address to
    ) public onlyOwner returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        amounts = _swap(amountIn, path);
        IERC20(path[path.length - 1]).transfer(to, amounts[amounts.length - 1]);

        emit BridgeSwapOut(path, amountIn, to);
    }

    /**
     * @dev helper swap function
     * @param amountIn the amount of token to swap
     * @param path token array
     */
    function _swap(
        uint256 amountIn,
        address[] calldata path
    ) private returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            address tokenA = path[i];
            address tokenB = path[i + 1];
            if (!isPoolExists[tokenA][tokenB]) revert InvalidPath();
            uint256 index = poolIndex[tokenA][tokenB];
            Pool storage temp = poolList[index];

            uint256 temp_amountOut;
            if (tokenA < tokenB) {
                temp_amountOut = BridgeSwapLibrary.getAmountOut(
                    amounts[i],
                    temp.reserve0,
                    temp.reserve1
                );
                temp.reserve0 += amounts[i];
                temp.reserve1 -= temp_amountOut;
            } else {
                temp_amountOut = BridgeSwapLibrary.getAmountOut(
                    amounts[i],
                    temp.reserve1,
                    temp.reserve0
                );
                temp.reserve1 += amounts[i];
                temp.reserve0 -= temp_amountOut;
            }
            amounts[i + 1] = temp_amountOut;
        }
    }

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
