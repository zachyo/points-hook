# Uniswap v4 Points Hook

This project implements a Uniswap v4 hook that rewards users with points for swapping ETH for a specific token in a pool. The points are issued as ERC1155 tokens.

## Features

- **Point Issuance**: Users receive points equivalent to 20% of the ETH value they swap.
- **Milestone Bonuses**: Users are rewarded with bonus points when their total trading volume in a pool reaches certain milestones:
    - **Milestone 1**: 100 bonus points when volume reaches 1 ETH.
    - **Milestone 2**: 500 bonus points when volume reaches 5 ETH.
- **ERC1155-based Points**: The points are implemented as ERC1155 tokens, where the token ID is the `poolId` of the Uniswap v4 pool.

## How it Works

The `PointsHook` contract inherits from Uniswap v4's `BaseHook` and Solmate's `ERC1155`. It uses the `afterSwap` hook to calculate and award points.

### `afterSwap`

The `afterSwap` hook is used because the exact amount of ETH spent in a swap is only known *after* the swap has been executed. This is crucial for accurately calculating the points to be awarded.

### `hookData`

To ensure points are awarded to the correct user, the hook requires the user's address to be passed in the `hookData` field when making a swap. If `hookData` is empty or does not contain a valid address, no points will be minted.

### Point Calculation and Milestones

1.  **Base Points**: For each eligible swap, the user is awarded points equal to 20% of the ETH amount they spent.
2.  **Volume Tracking**: The hook tracks the total ETH trading volume for each user in each pool.
3.  **Milestone Check**: After a swap, the hook checks if the user's new total volume has crossed any of the milestone thresholds. If a milestone is crossed, the corresponding bonus points are added to the points minted for the current swap.

## How to Use

1.  **Deploy the Hook**: Deploy the `PointsHook.sol` contract.
2.  **Initialize a Pool**: When creating a new Uniswap v4 pool, provide the address of the deployed `PointsHook` contract and set the `hooks` parameter to enable the `afterSwap` hook.
3.  **Perform a Swap**: To earn points, users must perform a swap on the pool, swapping ETH for the other token. The user's address must be encoded and passed in the `hookData` parameter of the swap transaction.

## Development and Testing

This project uses Foundry for development and testing.

### Setup

```bash
forge install
```

### Testing

To run the tests, execute the following command:

```bash
forge test
```

The tests in `test/PointsHook.t.sol` cover the following scenarios:
- Basic point issuance on a swap.
- Correct awarding of milestone bonuses when trading volume thresholds are crossed.