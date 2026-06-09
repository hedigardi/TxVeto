// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TxVetoSessionPolicy} from "../contracts/TxVetoSessionPolicy.sol";
import {TxVetoAARouterAdapter} from "../contracts/TxVetoAARouterAdapter.sol";

interface Vm {
    function envUint(string calldata key) external returns (uint256 value);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function serializeAddress(string calldata objectKey, string calldata valueKey, address value)
        external
        returns (string memory json);
    function writeJson(string calldata json, string calldata path) external;
}

/// @notice Foundry deployment script for TxVeto Step 4 contracts.
contract DeployTxVeto {
    address private constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    function run() external returns (address policyAddress, address adapterAddress) {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPk);

        TxVetoSessionPolicy policy = new TxVetoSessionPolicy();
        TxVetoAARouterAdapter adapter = new TxVetoAARouterAdapter(address(policy));

        vm.stopBroadcast();

        policyAddress = address(policy);
        adapterAddress = address(adapter);

        string memory json = vm.serializeAddress("deployment", "policy", policyAddress);
        json = vm.serializeAddress("deployment", "adapter", adapterAddress);
        vm.writeJson(json, "./deployments/latest.json");
    }
}
