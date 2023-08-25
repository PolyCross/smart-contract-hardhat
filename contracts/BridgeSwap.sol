// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./interfaces/IBridgeSwap.sol";
import "./libraries/BridgeSwapLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

struct Pool {
    address token0;
    address token1;
    uint256 reserve0;
    uint256 reserve1;
}

contract BridgeSwap is
    IBridgeSwap,
    ERC1155SupplyUpgradeable,
    OwnableUpgradeable
{
    function Initialize() public initializer {
        __ERC1155_init("");
        __Ownable_init();
    }

    Pool[] poolList;
    mapping(address => mapping(address => bool)) public isPoolExists;
    mapping(address => mapping(address => uint256)) poolIndex;

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
     * @param tokenA address of tokenA
     * @param tokenB address of tokenB
     * @return token0 address of token0
     * @return token1 address of token0
     * @return reserve0 amount of token0
     * @return reserve1 amount of token1
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
        if (!isPoolExists[tokenA][tokenB]) revert PoolNotExist();
        uint256 index = poolIndex[tokenA][tokenB];
        Pool memory targetPool = poolList[index];
        (token0, token1, reserve0, reserve1) = (
            targetPool.token0,
            targetPool.token1,
            targetPool.reserve0,
            targetPool.reserve1
        );
    }

    /**
     * @dev calculating the amount of tokens that can be obtained based on the input amount and path.
     * @param amountIn the amount of token to swap
     * @param path token array
     */
    function calculateAmountOut(
        uint256 amountIn,
        address[] calldata path
    ) public view returns (uint256) {
        if (path.length < 2) revert InvalidPath();
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint i; i < path.length - 1; i++) {
            address tokenA = path[i];
            address tokenB = path[i + 1];

            if (!isPoolExists[tokenA][tokenB]) revert PoolNotExist();

            uint256 index = poolIndex[tokenA][tokenB];
            Pool memory temp = poolList[index];

            uint256 reserve0 = temp.reserve0;
            uint256 reserve1 = temp.reserve1;

            uint256 temp_amountOut = tokenA < tokenB
                ? BridgeSwapLibrary.getAmountOut(amounts[i], reserve0, reserve1)
                : BridgeSwapLibrary.getAmountOut(
                    amounts[i],
                    reserve1,
                    reserve0
                );

            amounts[i + 1] = temp_amountOut;
        }

        return amounts[amounts.length - 1];
    }

    // ===================================================== Write Functions =====================================================

    /**
     * @dev add liquidity
     * @param tokenA address of tokenA
     * @param tokenB address of tokenB
     * @param amountA amount of tokenA
     * @param amountB amount of tokenB
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to
    ) public checkSameToken(tokenA, tokenB) returns (uint256 share) {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = BridgeSwapLibrary.sortTokenWithAmount(
                tokenA,
                tokenB,
                amountA,
                amountB
            );

        if (isPoolExists[tokenA][tokenB]) {
            uint256 index = poolIndex[tokenA][tokenB];

            Pool storage targetPool = poolList[index];
            uint256 _totalSupply = totalSupply(index);

            uint256 reserve0 = targetPool.reserve0;
            uint256 reserve1 = targetPool.reserve1;

            share = Math.min(
                (amount0 * _totalSupply) / reserve0,
                (amount1 * _totalSupply) / reserve1
            );
            targetPool.reserve0 += amount0;
            targetPool.reserve1 += amount1;

            _mint(to, index, share, "");
        } else {
            poolIndex[tokenA][tokenB] = poolList.length;
            poolIndex[tokenB][tokenA] = poolList.length;

            share = Math.sqrt(amountA * amountB);

            _mint(to, poolList.length, share, "");

            Pool memory newPool = Pool({
                token0: token0,
                token1: token1,
                reserve0: amount0,
                reserve1: amount1
            });

            poolList.push(newPool);

            isPoolExists[tokenA][tokenB] = true;
            isPoolExists[tokenB][tokenA] = true;
        }
        emit AddLiquidty(msg.sender, token0, token1, share, to);
    }

    /**
     * @dev swap exact tokens for tokens
     * @notice user op
     * @param amountIn the amount of token to swap
     * @param amountOutMin the expected minimum amount of tokens to be received
     * @param path token array
     * @return amounts the array of token out amount
     */
    function swapIn(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) public returns (uint256[] memory amounts) {
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
    function swapOut(
        uint256 amountIn,
        address[] calldata path,
        address to
    ) public onlyOwner returns (uint256[] memory amounts) {
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        amounts = _swap(amountIn, path);
        uint256 final_index = path.length - 1;      // gas saving, because path and amounts have the same length
        IERC20(path[final_index]).transfer(to, amounts[final_index]);

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
        if (path.length < 2) revert InvalidPath();
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint i; i < path.length - 1; i++) {
            address tokenA = path[i];
            address tokenB = path[i + 1];

            if (!isPoolExists[tokenA][tokenB]) revert PoolNotExist();

            uint256 index = poolIndex[tokenA][tokenB];
            Pool storage temp = poolList[index];

            uint256 temp_amountOut;
            uint256 reserve0 = temp.reserve0;
            uint256 reserve1 = temp.reserve1;

            if (tokenA < tokenB) {
                temp_amountOut = BridgeSwapLibrary.getAmountOut(
                    amounts[i],
                    reserve0,
                    reserve1
                );
                temp.reserve0 += amounts[i];
                temp.reserve1 -= temp_amountOut;
            } else {
                temp_amountOut = BridgeSwapLibrary.getAmountOut(
                    amounts[i],
                    reserve1,
                    reserve0
                );
                temp.reserve1 += amounts[i];
                temp.reserve0 -= temp_amountOut;
            }
            amounts[i + 1] = temp_amountOut;
        }
    }

    /**
     * @dev remove the liquidity
     * @param tokenA address of tokenA
     * @param tokenB address of tokenB
     * @param liquidity the liquidity amount to remove
     * @param to the receiver
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        address to
    )
        public
        checkSameToken(tokenA, tokenB)
        returns (uint256 amount0, uint256 amount1)
    {
        if (!isPoolExists[tokenA][tokenB]) revert PoolNotExist();
        uint256 index = poolIndex[tokenA][tokenB];

        Pool storage targetPool = poolList[index];
        uint256 total = totalSupply(index);
        amount0 = (targetPool.reserve0 * liquidity) / total;
        amount1 = (targetPool.reserve1 * liquidity) / total;
        targetPool.reserve0 -= amount0;
        targetPool.reserve1 -= amount1;

        _burn(msg.sender, index, liquidity);

        IERC20(targetPool.token0).transfer(to, amount0);
        IERC20(targetPool.token1).transfer(to, amount1);

        emit RemoveLiquidity(msg.sender, tokenA, tokenB, liquidity, to);
    }

    modifier checkSameToken(address tokenA, address tokenB) {
        if (tokenA == tokenB) revert SameToken();
        _;
    }
}
