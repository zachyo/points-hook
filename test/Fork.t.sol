// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
 
import "forge-std/Test.sol";
 
interface IERC20 {
    function balanceOf(address account) external view returns (uint);
}
 
contract ForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_WHALE = 0xd2DD7b597Fd2435b6dB61ddf48544fd931e6869F;
 
    uint forkId;
 
    // modifier to create and select a fork from MAINNET_RPC_URL env var
    modifier forked() {
        forkId = vm.createFork(vm.envString("FORK_URL"));
        vm.selectFork(forkId);
        _;
        // optionally: vm.selectFork(0) to switch back to default behavior
    }
 
    function testUSDCBalanceForked() public forked {
        uint balance = IERC20(USDC).balanceOf(USDC_WHALE);
        console.log("Whale balance (USDC):", balance / 1e6);
        assertGt(balance, 100_000 * 1e6, "Whale should have large balance");
    }
}