// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";

import "forge-std/console.sol";
import {PointsHook} from "../src/PointsHook.sol";

contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {
    MockERC20 token;

    Currency ethCurrency = Currency.wrap(address(0));
    Currency tokenCurrency;

    PointsHook hook;

    function setUp() public {
        // Step 1 + 2
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));

        // Mint a bunch of TOKEN to ourselves and to address(1)
        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);

        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo("PointsHook.sol", abi.encode(manager), address(flags));

        // Deploy our hook
        hook = PointsHook(address(flags));

        // Approve our TOKEN for spending on the swap router and modify liquidity router
        // These variables are coming from the `Deployers` contract
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);

        // Initialize a pool
        (key, ) = initPool(
            ethCurrency, // Currency 0 = ETH
            tokenCurrency, // Currency 1 = TOKEN
            hook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
        );

        // Add some liquidity to the pool
        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

        uint256 ethToAdd = 20 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickUpper,
            ethToAdd
        );
        uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1,
            liquidityDelta
        );

        modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(
            address(this),
            poolIdUint
        );

        // Set user address in hook data
        bytes memory hookData = abi.encode(address(this));

        // Now we swap
        // We will swap 0.001 ether for tokens
        // We should get 20% of 0.001 * 10**18 points
        // = 2 * 10**14
        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        uint256 pointsBalanceAfterSwap = hook.balanceOf(
            address(this),
            poolIdUint
        );
        console2.log("pointsBalanceAfterSwap1", pointsBalanceAfterSwap);

        assertEq(pointsBalanceAfterSwap - pointsBalanceOriginal, 2 * 10 ** 14);
    }

    function test_milestone1() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(
            address(this),
            poolIdUint
        );

        // Set user address in hook data
        bytes memory hookData = abi.encode(address(this));

        // Now we swap above 1 ether
        // We will swap 1.001 ether for tokens
        // We should get 20% of 1.001 * 10**18 points plus bonus points of 100 points
        // = (2.002 * 10**17) + 100
        swapRouter.swap{value: 1.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -1.001 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        uint256 pointsBalanceAfterSwap1 = hook.balanceOf(
            address(this),
            poolIdUint
        );
        console2.log("pointsBalanceOriginal", pointsBalanceOriginal);
        console2.log("pointsBalanceAfterSwap1", pointsBalanceAfterSwap1);

        assertEq(
            pointsBalanceAfterSwap1 - pointsBalanceOriginal,
            (2.002 * 10 ** 17) + 100
        );

        // MILESTONE 2
        // Now we swap above 5 ether
        // We will swap 5.001 ether for tokens
        // We should get 20% of 5.001 * 10**18 points plus bonus points of 100 points
        // = (10.002 * 10**17) + 500
        swapRouter.swap{value: 5.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -5.001 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        uint256 pointsBalanceAfterSwap2 = hook.balanceOf(
            address(this),
            poolIdUint
        );
        uint256 volumeTraded = hook.totalVolume(address(this), poolIdUint);
        console2.log("pointsBalanceAfterSwap2", pointsBalanceAfterSwap2);
        console2.log("total volumeTraded", volumeTraded);

        assertEq(
            pointsBalanceAfterSwap2 - pointsBalanceAfterSwap1,
            (10.002 * 10 ** 17) + 500
        );
    }

// this is to test milestones seperately
    // function test_milestone2() public {
    //     uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
    //     uint256 pointsBalanceOriginal = hook.balanceOf(
    //         address(this),
    //         poolIdUint
    //     );

    //     // Set user address in hook data
    //     bytes memory hookData = abi.encode(address(this));

    //     // Now we swap above 5 ether
    //     // We will swap 5.001 ether for tokens
    //     // We should get 20% of 5.001 * 10**18 points plus bonus points of 100 points
    //     // = (10.002 * 10**17) + 500
    //     swapRouter.swap{value: 5.001 ether}(
    //         key,
    //         SwapParams({
    //             zeroForOne: true,
    //             amountSpecified: -5.001 ether, // Exact input for output swap
    //             sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    //         }),
    //         PoolSwapTest.TestSettings({
    //             takeClaims: false,
    //             settleUsingBurn: false
    //         }),
    //         hookData
    //     );
    //     uint256 pointsBalanceAfterSwap = hook.balanceOf(
    //         address(this),
    //         poolIdUint
    //     );
    //     uint256 volumeTraded = hook.totalVolume(address(this), poolIdUint);
    //     console2.log("pointsBalanceOriginal", pointsBalanceOriginal);
    //     console2.log("pointsBalanceAfterSwap", pointsBalanceAfterSwap);
    //     console2.log("volumeTraded", volumeTraded);

    //     assertEq(
    //         pointsBalanceAfterSwap - pointsBalanceOriginal,
    //         (10.002 * 10 ** 17) + 500 + 100 // 100 is for previous swap
    //     );
    // }
}
