// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/TxVetoSessionPolicy.sol";
import "../contracts/TxVetoAARouterAdapter.sol";

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    function prank(address caller) external;
    function deal(address account, uint256 newBalance) external;
}

contract DummyTarget {
    uint256 public pingCount;

    function ping() external payable {
        pingCount += 1;
    }

    function pingNoValue() external {
        pingCount += 1;
    }
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount || balanceOf[from] < amount) {
            return false;
        }
        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract TxVetoSessionPolicyTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TxVetoSessionPolicy internal policy;
    TxVetoAARouterAdapter internal adapter;
    DummyTarget internal target;
    MockERC20 internal token;

    uint256 internal ownerPk;
    address internal owner;
    address internal sessionKey;

    function setUp() public {
        policy = new TxVetoSessionPolicy();
        adapter = new TxVetoAARouterAdapter(address(policy));
        target = new DummyTarget();
        token = new MockERC20();

        ownerPk = 0xA11CE;
        owner = vm.addr(ownerPk);
        sessionKey = address(0xBEEF);

        token.mint(owner, 1_000_000);
        vm.deal(address(policy), 10 ether);
    }

    function testCreateSessionWithSigAndExecuteNative() public {
        bytes32 sessionId = keccak256("native-session");

        TxVetoSessionPolicy.SessionConfigInput memory cfg = TxVetoSessionPolicy.SessionConfigInput({
            owner: owner,
            sessionKey: sessionKey,
            validAfter: uint64(block.timestamp),
            validUntil: uint64(block.timestamp + 1 days),
            periodSeconds: 1 hours,
            maxValuePerCall: 1 ether,
            maxValuePerPeriod: 2 ether,
            spendToken: address(0),
            maxTokenPerCall: 0,
            maxTokenPerPeriod: 0
        });

        (address[] memory targets, bytes4[][] memory selectorsByTarget) = _singleTargetPolicy();
        bytes32 salt = keccak256("test-salt-native");
        uint256 deadline = block.timestamp + 10 minutes;

        bytes32 digest = policy.getCreateSessionDigest(sessionId, cfg, targets, selectorsByTarget, deadline, salt);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        policy.createSessionWithSig(sessionId, cfg, targets, selectorsByTarget, deadline, salt, sig);

        vm.prank(sessionKey);
        policy.executeThroughSession(sessionId, address(target), 0.2 ether, abi.encodeWithSelector(target.ping.selector));

        require(target.pingCount() == 1, "native execution should call target");
    }

    function testExecuteTokenThroughSession() public {
        bytes32 sessionId = keccak256("token-session");

        TxVetoSessionPolicy.SessionConfigInput memory cfg = TxVetoSessionPolicy.SessionConfigInput({
            owner: owner,
            sessionKey: sessionKey,
            validAfter: uint64(block.timestamp),
            validUntil: uint64(block.timestamp + 1 days),
            periodSeconds: 1 hours,
            maxValuePerCall: 0,
            maxValuePerPeriod: 1,
            spendToken: address(token),
            maxTokenPerCall: 80,
            maxTokenPerPeriod: 100
        });

        (address[] memory targets, bytes4[][] memory selectorsByTarget) = _singleTargetPolicy();
        bytes32 salt = keccak256("test-salt-token");
        uint256 deadline = block.timestamp + 10 minutes;

        bytes32 digest = policy.getCreateSessionDigest(sessionId, cfg, targets, selectorsByTarget, deadline, salt);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        policy.createSessionWithSig(sessionId, cfg, targets, selectorsByTarget, deadline, salt, sig);

        vm.prank(owner);
        token.approve(address(policy), 100);

        vm.prank(sessionKey);
        policy.executeTokenThroughSession(
            sessionId,
            address(target),
            50,
            abi.encodeWithSelector(target.pingNoValue.selector)
        );

        require(token.balanceOf(address(target)) == 50, "target should receive tokens");
        require(target.pingCount() == 1, "token execution should call target");

        bool reverted = false;
        vm.prank(sessionKey);
        try
            policy.executeTokenThroughSession(
                sessionId,
                address(target),
                60,
                abi.encodeWithSelector(target.pingNoValue.selector)
            )
        {
            reverted = false;
        } catch {
            reverted = true;
        }

        require(reverted, "second token call should exceed period budget");
    }

    function testSafeAdapterRouteExecutesViaPolicy() public {
        bytes32 sessionId = keccak256("safe-adapter-native-session");

        TxVetoSessionPolicy.SessionConfigInput memory cfg = TxVetoSessionPolicy.SessionConfigInput({
            owner: owner,
            sessionKey: address(adapter),
            validAfter: uint64(block.timestamp),
            validUntil: uint64(block.timestamp + 1 days),
            periodSeconds: 1 hours,
            maxValuePerCall: 0.5 ether,
            maxValuePerPeriod: 1 ether,
            spendToken: address(0),
            maxTokenPerCall: 0,
            maxTokenPerPeriod: 0
        });

        (address[] memory targets, bytes4[][] memory selectorsByTarget) = _singleTargetPolicy();
        bytes32 salt = keccak256("safe-adapter-salt");
        uint256 deadline = block.timestamp + 10 minutes;

        bytes32 digest = policy.getCreateSessionDigest(sessionId, cfg, targets, selectorsByTarget, deadline, salt);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        policy.createSessionWithSig(sessionId, cfg, targets, selectorsByTarget, deadline, salt, sig);

        address safeAccount = address(0x51AFE);
        vm.prank(safeAccount);
        adapter.executeForSafe(sessionId, address(target), 0.1 ether, abi.encodeWithSelector(target.ping.selector));

        require(target.pingCount() == 1, "safe adapter path should execute target");
    }

    function _singleTargetPolicy() internal view returns (address[] memory targets, bytes4[][] memory selectorsByTarget) {
        targets = new address[](1);
        targets[0] = address(target);

        selectorsByTarget = new bytes4[][](1);
        selectorsByTarget[0] = new bytes4[](2);
        selectorsByTarget[0][0] = target.ping.selector;
        selectorsByTarget[0][1] = target.pingNoValue.selector;
    }
}
