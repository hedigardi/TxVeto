// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITxVetoSessionPolicy {
    function executeThroughSession(bytes32 sessionId, address target, uint256 value, bytes calldata data)
        external
        returns (bytes memory returnData);

    function executeTokenThroughSession(bytes32 sessionId, address target, uint256 tokenAmount, bytes calldata data)
        external
        returns (bytes memory returnData);
}

/// @title TxVetoAARouterAdapter
/// @notice Minimal Safe/Kernel-compatible adapter that routes AA execution through TxVeto policy checks.
/// @dev Configure sessionKey in TxVetoSessionPolicy to this adapter address.
contract TxVetoAARouterAdapter {
    address public immutable policy;

    event SafeRouteExecuted(bytes32 indexed sessionId, address indexed smartAccount, address indexed target, uint256 value);
    event KernelRouteExecuted(bytes32 indexed sessionId, address indexed smartAccount, address indexed target, uint256 value);
    event SafeTokenRouteExecuted(
        bytes32 indexed sessionId,
        address indexed smartAccount,
        address indexed target,
        uint256 tokenAmount
    );
    event KernelTokenRouteExecuted(
        bytes32 indexed sessionId,
        address indexed smartAccount,
        address indexed target,
        uint256 tokenAmount
    );

    constructor(address policyAddress) {
        require(policyAddress != address(0), "policy=0");
        policy = policyAddress;
    }

    function executeForSafe(bytes32 sessionId, address target, uint256 value, bytes calldata data)
        external
        returns (bytes memory returnData)
    {
        returnData = ITxVetoSessionPolicy(policy).executeThroughSession(sessionId, target, value, data);
        emit SafeRouteExecuted(sessionId, msg.sender, target, value);
    }

    function executeForKernel(bytes32 sessionId, address target, uint256 value, bytes calldata data)
        external
        returns (bytes memory returnData)
    {
        returnData = ITxVetoSessionPolicy(policy).executeThroughSession(sessionId, target, value, data);
        emit KernelRouteExecuted(sessionId, msg.sender, target, value);
    }

    function executeTokenForSafe(bytes32 sessionId, address target, uint256 tokenAmount, bytes calldata data)
        external
        returns (bytes memory returnData)
    {
        returnData = ITxVetoSessionPolicy(policy).executeTokenThroughSession(sessionId, target, tokenAmount, data);
        emit SafeTokenRouteExecuted(sessionId, msg.sender, target, tokenAmount);
    }

    function executeTokenForKernel(bytes32 sessionId, address target, uint256 tokenAmount, bytes calldata data)
        external
        returns (bytes memory returnData)
    {
        returnData = ITxVetoSessionPolicy(policy).executeTokenThroughSession(sessionId, target, tokenAmount, data);
        emit KernelTokenRouteExecuted(sessionId, msg.sender, target, tokenAmount);
    }
}
