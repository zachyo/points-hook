// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/PointsHook.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract DeployHook is Script {
    function run() external {
        // user pkey for transaction
        uint privateKey = vm.envUint("PRIVATE_KEY");
        
        // https://docs.uniswap.org/contracts/v4/deployments (deploy on any chain you wish) (currently on base sepolia)
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");

        // https://getfoundry.sh/guides/deterministic-deployments-using-create2/#getting-started
        address create2Deployer = vm.envAddress("CREATE2_DEPLOYER");

        // TODO: Implement HookMiner logic to generate salt for valid hook address

        // For v4 hooks, you need to mine a salt that produces an address
        // with specific leading bits matching the hook permissions
        // The address determines which hooks are enabled

        // Salt has been mined outside off chain
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        (address expectedHookAddy, bytes32 salt) = HookMiner.find(
            create2Deployer,
            flags,
            type(PointsHook).creationCode,
            abi.encode(IPoolManager(poolManager))
        );

        console.log("Expected hook address:", expectedHookAddy);
        console.log("Deployer address:", create2Deployer);
        console.logBytes32(salt);

        vm.startBroadcast(privateKey);

        PointsHook hook = new PointsHook{salt: salt}(IPoolManager(poolManager));
        require(
            address(hook) == expectedHookAddy,
            "PointsHookScript: hook address mismatch"
        );

        vm.stopBroadcast();
    }
}


// Live run: forge script script/DeployHook.s.sol --rpc-url $RPC_URL --chain-id <<chain of your choice>> --broadcast --verify
//  remove broadcast and verify flags for testing purposes