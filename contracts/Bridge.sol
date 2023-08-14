// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./interfaces/IBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bridge is IBridge, Ownable {
    mapping(address => bool) public isSupported;
    mapping(address => uint256) public reserve;

    /**
     * @dev bridge token in
     * @notice user op
     * @param token ERC20 token address
     * @param amount token amount
     */
    function bridgeIn(
        address token,
        uint256 amount,
        address receiver
    ) public checkTokenSupport(token) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        reserve[token] -= amount;

        emit BridgeIn(receiver, token, amount);
    }

    /**
     * @dev bridge token out
     * @notice admin op
     * @param token ERC20 token address
     * @param amount token amount
     * @param to receiver address
     */
    function bridgeOut(
        address token,
        uint256 amount,
        address to
    ) public checkTokenSupport(token) onlyOwner {
        IERC20(token).transfer(to, amount);
        reserve[token] -= amount;

        emit BridgeOut(to, token, amount);
    }

    /**
     * @dev supoort new token
     * @notice admin op
     * @param token new supported token address
     */
    function supportNewToken(address token) public onlyOwner {
        if (isSupported[token]) revert("Token Already Supported");
        isSupported[token] = true;
    }

    /**
     * @dev add token reserve
     * @notice admin op
     * @param token ERC20 token address
     * @param amount token amount
     */
    function addReserve(
        address token,
        uint256 amount
    ) public checkTokenSupport(token) onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        reserve[token] += amount;
    }

    /**
     * @dev check if the token is supported, if not then revert
     */
    modifier checkTokenSupport(address token) {
        if (!isSupported[token]) revert TokenNotSupport();
        _;
    }
}
