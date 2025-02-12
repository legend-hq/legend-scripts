# Quark Scripts

## Overview

Quark is an Ethereum smart contract wallet system, designed to run custom code — termed Quark Operations — with each transaction. Quark scripts are the custom code that run in the context of a Quark wallet. Scripts are versatile and allow Quark wallets to execute any arbitrary code, which can enable use-cases such as flashloaning and repaying a borrow in a single transaction.

## Quark Script Features

### Replayable Scripts

Replayable scripts are Quark scripts that can re-executed multiple times using the same signature of a _Quark operation_. More specifically, replayable scripts explicitly clear the nonce used by the transaction (can be done via the `allowReplay` helper function in [`QuarkScript.sol`](./lib/quark/src/quark-core/src/QuarkScript.sol)) to allow for the same nonce to be re-used with the same script address.

An example use-case for replayable scripts is recurring purchases. If a user wanted to buy X WETH using 1,000 USDC every Wednesday until 10,000 USDC is spent, they can achieve this by signing a single _Quark operation_ of a replayable script ([example](./src/RecurringSwap.sol)). A submitter can then submit this same signed _Quark operation_ every Wednesday to execute the recurring purchase. The replayable script should have checks to ensure conditions are met before purchasing the WETH.

#### Same script address, but different calldata

For replayable transactions where the nonce is cleared, _Quark State Manager_ requires future transactions using that nonce to use the same script. This is to ensure that the same nonce is not accidentally used by two different scripts. However, it does not require the `calldata` passed to that script to be the same. This means that a cleared nonce can be executed with the same script but different calldata.

Allowing the calldata to change greatly increases the flexibility of replayable scripts. One can think of a replayable script like a sub-module of a wallet that supports different functionality. In the [example script](./src/RecurringSwap.sol) for recurring purchases, there is a separate `cancel` function that the user can sign to cancel the nonce, and therefore, cancel all the recurring purchases that use this nonce. The user can also also sign multiple `purchase` calls, each with different purchase configurations. This means that multiple variations of recurring purchases can exist on the same nonce and can all be cancelled together.

One danger of flexible `calldata` in replayable scripts is that previously signed `calldata` can always be re-executed. The Quark system does not disallow previously used calldata when a new calldata is executed. This means that scripts may need to implement their own method of invalidating previously-used `calldata`.

### Callbacks

Callbacks are an opt-in feature of Quark scripts that allow for an external contract to call into the Quark script (in the context of the _Quark wallet_) during the same transaction. An example use-case of callbacks is Uniswap flashloans ([example script](./src/UniswapFlashLoan.sol)), where the Uniswap pool will call back into the _Quark wallet_ to make sure that the loan is paid off before ending the transaction.

Callbacks need to be explicitly turned on by Quark scripts. Specifically, this is done by writing the callback target address to the callback storage slot in _Quark State Manager_ (can be done via the `allowCallback` helper function in [`QuarkScript.sol`](./lib/quark/src/quark-core/src/QuarkScript.sol)).

## Quark Builder

[Quark Builder](./src/builder/QuarkBuilder.sol) is a contract of functions that simplifies the complexities around building _Quark operations_. The code is written in Solidity, but not meant to be deployed on-chain. Rather, it is designed to run locally in a client to construct _Quark operations_ based on user intents (e.g. "transfer 5 USDC to 0xABC... on chain 10").

[Quark Builder Helper](./src/builder/QuarkBuilderHelper.sol) is a contract with functions outside of constructing _Quark operations_ that might still be helpful for those using the QuarkBuilder. For example, there is a helper function to determine the bridgeability of assets on different chains.

## Fork tests and MAINNET_RPC_URL

Some tests require forking mainnet, e.g. to exercise use-cases like
supplying and borrowing in a comet market.

The "fork url" is specified using the environment variable `MAINNET_RPC_URL`.
It can be any node provider for Ethereum mainnet, such as Infura or Alchemy.

The environment variable can be set when running tests, like so:

```
$ MAINNET_RPC_URL=... forge test
```

## Updating gas snapshots

In CI we compare gas snapshots against a committed baseline (stored in
`.gas-snapshot`), and the job fails if any diff in the snapshot exceeds a
set threshold from the baseline.

You can accept the diff and update the baseline if the increased gas usage
is intentional. Just run the following command:

```sh
$ MAINNET_RPC_URL=... ./script/update-snapshot.sh
```

Then commit the updated snapshot file:

```sh
$ git add .gas-snapshot && git commit -m "commit new baseline gas snapshot"
```

## Deploy

To deploy all un-deployed contracts in this repo (not-including `QuarkBuilder`), run the following command:

```sh
set -a && source .env && ./script/deploy_contracts/deploy-contracts.sh --broadcast
```

Make sure the following env variables are defined:

```sh
# Required
RPC_URL=
ETHERSCAN_API_KEY=
DEPLOYMENT_CHAIN_ID=
DEPLOYER_PK=
```

## Verify

The deploy script should automatically verify contracts. However, sometimes contracts may be deployed outside of the script or verification may transiently fail. To deploy all scripts in this repo, the verification script can be run via:

```sh
set -a && source .env && ./script/verify_contracts/verify-contracts.sh
```

Make sure the following env variables are defined:

```sh
# Required
RPC_URL=
ETHERSCAN_API_KEY=
VERIFICATION_CHAIN_ID=
```

## CodeJar Deployments

Using artifacts from [release-v2024-03-27+2249648](https://github.com/compound-finance/quark/releases/tag/release-v2024-03-27%2B2249648).

| Network           | CodeJar Address                            |
| ----------------- | ------------------------------------------ |
| Mainnet           | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |
| Base              | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |
| Sepolia           | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |
| Arbitrum          | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |
| Optimism          | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |
| Polygon           | Pending |
| Scroll            | Pending |
| Base Sepolia      | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |
| Arbitrum Sepolia  | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |
| Optimism Sepolia  | 0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8 |