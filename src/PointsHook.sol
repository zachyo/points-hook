// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC1155 {
    // Track total trading volume per user per pool
    mapping(address => mapping(uint256 => uint256)) public totalVolume;

    // Milestone thresholds (in wei)
    uint256 public constant MILESTONE_1 = 1 ether; // 1 ETH
    uint256 public constant MILESTONE_2 = 5 ether; // 5 ETH

    // Milestone bonus points
    uint256 public constant BONUS_1 = 100 * 10 ** 18; // 100 points
    uint256 public constant BONUS_2 = 500 * 10 ** 18; // 500 points

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // If this is not an ETH-TOKEN pool with this hook attached, ignore
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        // We only mint points if user is buying TOKEN with ETH
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        // Mint points equal to 20% of the amount of ETH they spent
        // Since it's a zeroForOne swap:
        // if amountSpecified < 0:
        //      this is an "exact input for output" swap
        //      amount of ETH they spent is equal to |amountSpecified|
        //      uint256 ethSpendAmount = uint256(-swapParams.amountSpecified);
        // if amountSpecified > 0:
        //      this is an "exact output for input" swap
        //      amount of ETH they spent is equal to BalanceDelta.amount0()
        //      uint256 ethSpendAmount = uint256(int256(-delta.amount0()));

        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 pointsForSwap = ethSpendAmount / 5;

        // Mint the points
        _assignPoints(key.toId(), hookData, pointsForSwap, ethSpendAmount);

        return (this.afterSwap.selector, 0);
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 points,
        uint256 ethSpendAmount
    ) internal {
        // If no hookData is passed in, no points will be assigned to anyone
        if (hookData.length == 0) return;

        // Extract user address from hookData
        address user = abi.decode(hookData, (address));

        // If there is hookData but not in the format we're expecting and user address is zero
        // nobody gets any points
        if (user == address(0)) return;

        // Mint points to the user
        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));

        // Track previous volume before update
        uint256 previousVolume = totalVolume[user][poolIdUint];
        uint256 newVolume = previousVolume + ethSpendAmount;

        // Update total volume
        totalVolume[user][poolIdUint] = newVolume;
        uint256 newPointsToMint = _checkAndAddMilestoneBonuses(
            points,
            previousVolume,
            newVolume
        );

        _mint(user, poolIdUint, newPointsToMint, "");
    }

    // This checks
    // There has to be a way to also balance whales who directly use large amount above the whole milestone (remember to do this)
    function _checkAndAddMilestoneBonuses(
        uint256 points,
        uint256 previousVolume,
        uint256 newVolume
    ) internal pure returns (uint256 newPointsToMint) {

        newPointsToMint = points;

        // Check Milestone 1: 1 ETH
        if (newVolume >= MILESTONE_1 && previousVolume < MILESTONE_1) {
            newPointsToMint += BONUS_1;
        }

        // Check Milestone 2: 5 ETH
        if (newVolume >= MILESTONE_2 && previousVolume < MILESTONE_2) {
            newPointsToMint += BONUS_2;
        }
    }
}
