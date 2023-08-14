// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IBridge {
    error TokenNotSupport();

    function bridgeIn(address token, uint256 amount, address operator) external;

    function bridgeOut(address token, uint256 amount, address to) external;

    function supportNewToken(address token) external;

    function addReserve(address token, uint256 amount) external;

    event BridgeIn(
        address indexed receiver,
        address indexed token,
        uint256 amount
    );
    event BridgeOut(
        address indexed receiver,
        address indexed token,
        uint256 amount
    );
}
