// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IBridge {
    error SameToken();
    error PoolExists();

    event BridgeTransfer(address indexed token, uint256 amount);
    event BridgeSwap(address indexed fromToken, address indexed toToken, uint256 amount);
}