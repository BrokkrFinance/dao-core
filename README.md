[![Unit Tests](https://github.com/block42-blockchain-company/dao-core/actions/workflows/test.yml/badge.svg)](https://github.com/block42-blockchain-company/dao-core/actions/workflows/test.yml)
[![Linter Check](https://github.com/block42-blockchain-company/dao-core/actions/workflows/lint.yml/badge.svg)](https://github.com/block42-blockchain-company/dao-core/actions/workflows/lint.yml)
[![Coverage Check](https://github.com/block42-blockchain-company/dao-core/actions/workflows/coverage.yml/badge.svg)](https://github.com/block42-blockchain-company/dao-core/actions/workflows/coverage.yml)
[![MythXBadge](https://badgen.net/https/api.mythx.io/v1/projects/12ffa770-e566-4204-9917-0b90401125d6/badge/data?cache=300&icon=https://raw.githubusercontent.com/ConsenSys/mythx-github-badge/main/logo_white.svg)](https://docs.mythx.io/dashboard/github-badges)

# Brokkr Protocol ("Brotocol") Core Contracts

All contracts related to the BRO token.

In case you have improvement ideas or questions, you can reach us via [discord](https://discord.com/invite/CDNKYTDqTE),
or open an issue in this repository.

## Architecture Diagram

![architecture diagram](./static/architecture.jpg "Architecture Diagram")

## Contracts

| Name                                                 | Description                                                          |
| ---------------------------------------------------- | -------------------------------------------------------------------- |
| [`Airdrop`](contracts/Airdrop.sol)                   | Eligible wallets can claim BRO                                       |
| [`BBroToken`](contracts/BBroToken.sol)               | Non-transferable ERC20 token                                         |
| [`BroToken`](contracts/BroToken.sol)                 | ERC20 token                                                          |
| [`BondingV1`](contracts/BondingV1.sol)               | Send bonding token, claim discounted BRO or stake inside staking     |
| [`EpochManager`](contracts/EpochManager.sol)         | Stores global information needed for multiple contracts              |
| [`ProtocolMigrator`](contracts/ProtocolMigrator.sol) | Is used to migrate protocol state from Terra -> Avax                 |
| [`StakingV1`](contracts/StakingV1.sol)               | Stake BRO, claim BRO and bBRO                                        |
| [`TokenDistributor`](contracts/TokenDistributor.sol) | Transfers BRO from the rewards pool to bonding and staking contracts |
| [`Treasury`](contracts/Treasury.sol)                 | Holds any funds                                                      |
| [`TWAPOracle`](contracts/TWAPOracle.sol)             | TWAP oracles for bonding                                             |
| [`Vesting`](contracts/Vesting.sol)                   | Eligible wallets can claim BRO according to the schedules            |

## Testing

Run unit tests via

```
yarn test
```

## How to build

Compile the contracts to wasm files with

```
yarn compile
```

## Deployment

TBD

## Basic CI

- Unit tests check
- Linter check
- Coverage check
