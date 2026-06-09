// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title TxVetoSessionPolicy
/// @notice Thin-slice policy gateway for session-key-based agent execution.
/// @dev This contract is intentionally simple for Step 4 validation.
contract TxVetoSessionPolicy {
    error Unauthorized();
    error SessionNotActive(bytes32 sessionId);
    error SessionOutsideTimeWindow(bytes32 sessionId, uint256 nowTs);
    error TargetNotAllowed(bytes32 sessionId, address target);
    error SelectorNotAllowed(bytes32 sessionId, address target, bytes4 selector);
    error MaxValuePerCallExceeded(bytes32 sessionId, uint256 attempted, uint256 maxAllowed);
    error PeriodBudgetExceeded(bytes32 sessionId, uint256 attempted, uint256 maxAllowed);
    error MaxTokenPerCallExceeded(bytes32 sessionId, uint256 attempted, uint256 maxAllowed);
    error TokenPeriodBudgetExceeded(bytes32 sessionId, uint256 attempted, uint256 maxAllowed);
    error TokenNotConfigured(bytes32 sessionId);
    error TokenTransferFailed(bytes32 sessionId, address token, uint256 amount);
    error SignatureExpired(uint256 deadline, uint256 nowTs);
    error InvalidSignature();
    error SignatureAlreadyUsed(bytes32 digest);
    error InvalidSessionConfig();
    error CallFailed(bytes32 sessionId, address target, bytes returnData);

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private constant CREATE_SESSION_TYPEHASH = keccak256(
        "CreateSession(bytes32 sessionId,address owner,address sessionKey,uint64 validAfter,uint64 validUntil,uint64 periodSeconds,uint256 maxValuePerCall,uint256 maxValuePerPeriod,address spendToken,uint256 maxTokenPerCall,uint256 maxTokenPerPeriod,bytes32 policyHash,uint256 sigDeadline,bytes32 salt)"
    );

    struct SessionConfig {
        address owner;
        address sessionKey;
        uint64 validAfter;
        uint64 validUntil;
        uint64 periodSeconds;
        uint256 maxValuePerCall;
        uint256 maxValuePerPeriod;
        address spendToken;
        uint256 maxTokenPerCall;
        uint256 maxTokenPerPeriod;
        bool active;
    }

    struct SessionUsage {
        uint64 windowStartedAt;
        uint64 nonce;
        uint256 spentInWindow;
        uint256 tokenSpentInWindow;
    }

    struct SessionConfigInput {
        address owner;
        address sessionKey;
        uint64 validAfter;
        uint64 validUntil;
        uint64 periodSeconds;
        uint256 maxValuePerCall;
        uint256 maxValuePerPeriod;
        address spendToken;
        uint256 maxTokenPerCall;
        uint256 maxTokenPerPeriod;
    }

    event SessionCreated(
        bytes32 indexed sessionId,
        address indexed owner,
        address indexed sessionKey,
        uint64 validAfter,
        uint64 validUntil,
        uint64 periodSeconds,
        uint256 maxValuePerCall,
        uint256 maxValuePerPeriod,
        address spendToken,
        uint256 maxTokenPerCall,
        uint256 maxTokenPerPeriod
    );

    event SessionRevoked(bytes32 indexed sessionId, address indexed revokedBy);

    event SessionExecuted(
        bytes32 indexed sessionId,
        address indexed sessionKey,
        address indexed target,
        bytes4 selector,
        uint256 value,
        uint256 spentInWindow,
        uint64 nonce
    );

    event SessionTokenExecuted(
        bytes32 indexed sessionId,
        address indexed sessionKey,
        address indexed target,
        bytes4 selector,
        address token,
        uint256 tokenAmount,
        uint256 tokenSpentInWindow,
        uint64 nonce
    );

    event SessionCreatedBySignature(bytes32 indexed sessionId, bytes32 indexed digest, address indexed relayer);

    address public immutable admin;
    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(bytes32 => SessionConfig) public sessions;
    mapping(bytes32 => SessionUsage) public usages;
    mapping(bytes32 => mapping(address => bool)) public allowedTargets;
    mapping(bytes32 => mapping(address => bool)) public allowAllSelectorsForTarget;
    mapping(bytes32 => mapping(address => mapping(bytes4 => bool))) public allowedSelectors;
    mapping(bytes32 => bool) public usedDigests;

    constructor() {
        admin = msg.sender;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("TxVetoSessionPolicy")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    receive() external payable {}

    function createSession(
        bytes32 sessionId,
        SessionConfigInput calldata cfg,
        address[] calldata targets,
        bytes4[][] calldata selectorsByTarget
    ) external {
        if (msg.sender != admin && msg.sender != cfg.owner) {
            revert Unauthorized();
        }
        _createSession(sessionId, cfg, targets, selectorsByTarget);
    }

    function createSessionWithSig(
        bytes32 sessionId,
        SessionConfigInput calldata cfg,
        address[] calldata targets,
        bytes4[][] calldata selectorsByTarget,
        uint256 sigDeadline,
        bytes32 salt,
        bytes calldata signature
    ) external {
        uint256 nowTs = block.timestamp;
        if (nowTs > sigDeadline) {
            revert SignatureExpired(sigDeadline, nowTs);
        }

        bytes32 digest = _createSessionDigest(sessionId, cfg, targets, selectorsByTarget, sigDeadline, salt);
        if (usedDigests[digest]) {
            revert SignatureAlreadyUsed(digest);
        }

        address recovered = _recoverSigner(digest, signature);
        if (recovered == address(0) || recovered != cfg.owner) {
            revert InvalidSignature();
        }

        usedDigests[digest] = true;
        _createSession(sessionId, cfg, targets, selectorsByTarget);
        emit SessionCreatedBySignature(sessionId, digest, msg.sender);
    }

    function revokeSession(bytes32 sessionId) external {
        SessionConfig storage cfg = sessions[sessionId];
        if (!cfg.active) {
            revert SessionNotActive(sessionId);
        }
        if (msg.sender != admin && msg.sender != cfg.owner) {
            revert Unauthorized();
        }

        cfg.active = false;
        emit SessionRevoked(sessionId, msg.sender);
    }

    /// @notice Executes a call if all session policies pass.
    /// @dev Policy checks happen at execution time so clients can avoid fragile pre-validation assumptions.
    function executeThroughSession(bytes32 sessionId, address target, uint256 value, bytes calldata data)
        external
        returns (bytes memory returnData)
    {
        SessionConfig storage cfg = sessions[sessionId];
        if (!cfg.active) {
            revert SessionNotActive(sessionId);
        }
        if (msg.sender != cfg.sessionKey) {
            revert Unauthorized();
        }

        uint256 nowTs = block.timestamp;
        if (nowTs < cfg.validAfter || nowTs > cfg.validUntil) {
            revert SessionOutsideTimeWindow(sessionId, nowTs);
        }
        if (!allowedTargets[sessionId][target]) {
            revert TargetNotAllowed(sessionId, target);
        }

        bytes4 selector = _selectorOf(data);
        if (!allowAllSelectorsForTarget[sessionId][target]) {
            if (!allowedSelectors[sessionId][target][selector]) {
                revert SelectorNotAllowed(sessionId, target, selector);
            }
        }

        if (value > cfg.maxValuePerCall) {
            revert MaxValuePerCallExceeded(sessionId, value, cfg.maxValuePerCall);
        }

        SessionUsage storage usage = usages[sessionId];
        _refreshUsageWindow(cfg, usage, nowTs);

        uint256 newSpent = usage.spentInWindow + value;
        if (newSpent > cfg.maxValuePerPeriod) {
            revert PeriodBudgetExceeded(sessionId, newSpent, cfg.maxValuePerPeriod);
        }

        usage.spentInWindow = newSpent;
        usage.nonce += 1;

        (bool ok, bytes memory result) = target.call{value: value}(data);
        if (!ok) {
            revert CallFailed(sessionId, target, result);
        }

        emit SessionExecuted(sessionId, msg.sender, target, selector, value, usage.spentInWindow, usage.nonce);
        return result;
    }

    function executeTokenThroughSession(bytes32 sessionId, address target, uint256 tokenAmount, bytes calldata data)
        external
        returns (bytes memory returnData)
    {
        SessionConfig storage cfg = sessions[sessionId];
        if (!cfg.active) {
            revert SessionNotActive(sessionId);
        }
        if (msg.sender != cfg.sessionKey) {
            revert Unauthorized();
        }

        uint256 nowTs = block.timestamp;
        if (nowTs < cfg.validAfter || nowTs > cfg.validUntil) {
            revert SessionOutsideTimeWindow(sessionId, nowTs);
        }
        if (!allowedTargets[sessionId][target]) {
            revert TargetNotAllowed(sessionId, target);
        }

        bytes4 selector = _selectorOf(data);
        if (!allowAllSelectorsForTarget[sessionId][target]) {
            if (!allowedSelectors[sessionId][target][selector]) {
                revert SelectorNotAllowed(sessionId, target, selector);
            }
        }

        if (cfg.spendToken == address(0)) {
            revert TokenNotConfigured(sessionId);
        }
        if (tokenAmount > cfg.maxTokenPerCall) {
            revert MaxTokenPerCallExceeded(sessionId, tokenAmount, cfg.maxTokenPerCall);
        }

        SessionUsage storage usage = usages[sessionId];
        _refreshUsageWindow(cfg, usage, nowTs);

        uint256 newTokenSpent = usage.tokenSpentInWindow + tokenAmount;
        if (newTokenSpent > cfg.maxTokenPerPeriod) {
            revert TokenPeriodBudgetExceeded(sessionId, newTokenSpent, cfg.maxTokenPerPeriod);
        }

        usage.tokenSpentInWindow = newTokenSpent;
        usage.nonce += 1;

        bool transferred = IERC20(cfg.spendToken).transferFrom(cfg.owner, target, tokenAmount);
        if (!transferred) {
            revert TokenTransferFailed(sessionId, cfg.spendToken, tokenAmount);
        }

        (bool ok, bytes memory result) = target.call(data);
        if (!ok) {
            revert CallFailed(sessionId, target, result);
        }

        emit SessionTokenExecuted(
            sessionId,
            msg.sender,
            target,
            selector,
            cfg.spendToken,
            tokenAmount,
            usage.tokenSpentInWindow,
            usage.nonce
        );
        return result;
    }

    function getCreateSessionDigest(
        bytes32 sessionId,
        SessionConfigInput calldata cfg,
        address[] calldata targets,
        bytes4[][] calldata selectorsByTarget,
        uint256 sigDeadline,
        bytes32 salt
    ) external view returns (bytes32 digest) {
        return _createSessionDigest(sessionId, cfg, targets, selectorsByTarget, sigDeadline, salt);
    }

    function isAllowed(bytes32 sessionId, address target, bytes4 selector)
        external
        view
        returns (bool allowed, string memory reason)
    {
        SessionConfig storage cfg = sessions[sessionId];
        if (!cfg.active) {
            return (false, "session_inactive");
        }
        uint256 nowTs = block.timestamp;
        if (nowTs < cfg.validAfter || nowTs > cfg.validUntil) {
            return (false, "session_outside_time_window");
        }
        if (!allowedTargets[sessionId][target]) {
            return (false, "target_not_allowed");
        }
        if (allowAllSelectorsForTarget[sessionId][target]) {
            return (true, "ok");
        }
        if (!allowedSelectors[sessionId][target][selector]) {
            return (false, "selector_not_allowed");
        }
        return (true, "ok");
    }

    function _selectorOf(bytes calldata data) internal pure returns (bytes4 selector) {
        if (data.length < 4) {
            return bytes4(0);
        }
        assembly {
            selector := calldataload(data.offset)
        }
    }

    function _createSession(
        bytes32 sessionId,
        SessionConfigInput calldata cfg,
        address[] calldata targets,
        bytes4[][] calldata selectorsByTarget
    ) internal {
        _validateSessionConfig(sessionId, cfg, targets, selectorsByTarget);

        SessionConfig storage existing = sessions[sessionId];
        if (existing.active) {
            revert InvalidSessionConfig();
        }

        sessions[sessionId] = SessionConfig({
            owner: cfg.owner,
            sessionKey: cfg.sessionKey,
            validAfter: cfg.validAfter,
            validUntil: cfg.validUntil,
            periodSeconds: cfg.periodSeconds,
            maxValuePerCall: cfg.maxValuePerCall,
            maxValuePerPeriod: cfg.maxValuePerPeriod,
            spendToken: cfg.spendToken,
            maxTokenPerCall: cfg.maxTokenPerCall,
            maxTokenPerPeriod: cfg.maxTokenPerPeriod,
            active: true
        });

        usages[sessionId] = SessionUsage({
            windowStartedAt: uint64(block.timestamp),
            nonce: 0,
            spentInWindow: 0,
            tokenSpentInWindow: 0
        });

        uint256 i = 0;
        for (; i < targets.length; i++) {
            address target = targets[i];
            allowedTargets[sessionId][target] = true;

            bytes4[] calldata selectors = selectorsByTarget[i];
            if (selectors.length == 0) {
                allowAllSelectorsForTarget[sessionId][target] = true;
                continue;
            }

            uint256 j = 0;
            for (; j < selectors.length; j++) {
                allowedSelectors[sessionId][target][selectors[j]] = true;
            }
        }

        emit SessionCreated(
            sessionId,
            cfg.owner,
            cfg.sessionKey,
            cfg.validAfter,
            cfg.validUntil,
            cfg.periodSeconds,
            cfg.maxValuePerCall,
            cfg.maxValuePerPeriod,
            cfg.spendToken,
            cfg.maxTokenPerCall,
            cfg.maxTokenPerPeriod
        );
    }

    function _validateSessionConfig(
        bytes32 sessionId,
        SessionConfigInput calldata cfg,
        address[] calldata targets,
        bytes4[][] calldata selectorsByTarget
    ) internal pure {
        if (
            sessionId == bytes32(0) ||
            cfg.owner == address(0) ||
            cfg.sessionKey == address(0) ||
            cfg.validUntil <= cfg.validAfter ||
            cfg.periodSeconds == 0 ||
            cfg.maxValuePerPeriod == 0 ||
            cfg.maxValuePerCall > cfg.maxValuePerPeriod ||
            targets.length == 0 ||
            targets.length != selectorsByTarget.length
        ) {
            revert InvalidSessionConfig();
        }

        if (cfg.spendToken == address(0)) {
            if (cfg.maxTokenPerCall != 0 || cfg.maxTokenPerPeriod != 0) {
                revert InvalidSessionConfig();
            }
        } else {
            if (cfg.maxTokenPerPeriod == 0 || cfg.maxTokenPerCall > cfg.maxTokenPerPeriod) {
                revert InvalidSessionConfig();
            }
        }

        uint256 i = 0;
        for (; i < targets.length; i++) {
            if (targets[i] == address(0)) {
                revert InvalidSessionConfig();
            }
        }
    }

    function _refreshUsageWindow(SessionConfig storage cfg, SessionUsage storage usage, uint256 nowTs) internal {
        uint256 windowEnd = uint256(usage.windowStartedAt) + uint256(cfg.periodSeconds);
        if (nowTs > windowEnd) {
            usage.windowStartedAt = uint64(nowTs);
            usage.spentInWindow = 0;
            usage.tokenSpentInWindow = 0;
        }
    }

    function _createSessionDigest(
        bytes32 sessionId,
        SessionConfigInput calldata cfg,
        address[] calldata targets,
        bytes4[][] calldata selectorsByTarget,
        uint256 sigDeadline,
        bytes32 salt
    ) internal view returns (bytes32 digest) {
        _validateSessionConfig(sessionId, cfg, targets, selectorsByTarget);

        bytes32 policyHash = _policyHash(targets, selectorsByTarget);
        bytes32 structHash = keccak256(
            abi.encode(
                CREATE_SESSION_TYPEHASH,
                sessionId,
                cfg.owner,
                cfg.sessionKey,
                cfg.validAfter,
                cfg.validUntil,
                cfg.periodSeconds,
                cfg.maxValuePerCall,
                cfg.maxValuePerPeriod,
                cfg.spendToken,
                cfg.maxTokenPerCall,
                cfg.maxTokenPerPeriod,
                policyHash,
                sigDeadline,
                salt
            )
        );
        digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function _policyHash(address[] calldata targets, bytes4[][] calldata selectorsByTarget)
        internal
        pure
        returns (bytes32 h)
    {
        h = keccak256(abi.encodePacked(uint256(0)));

        uint256 i = 0;
        for (; i < targets.length; i++) {
            bytes4[] calldata selectors = selectorsByTarget[i];
            bytes32 selectorsHash = keccak256(abi.encodePacked(selectors));
            h = keccak256(abi.encode(h, targets[i], selectorsHash));
        }
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address signer) {
        if (signature.length != 65) {
            return address(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return address(0);
        }
        signer = ecrecover(digest, v, r, s);
    }
}
