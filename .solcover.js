module.exports = {
  skipFiles: [
    "mocks/MockStaking.sol",
    "ProtocolMigrator.sol",
    "TWAPOracle.sol",
    "libraries/FixedPoint.sol",
    "libraries/UQ112x112.sol",
    "libraries/TWAPLib.sol",
    "oracles/OnePoolTWAPOracle.sol",
    "oracles/TwoPoolTWAPOracle.sol",
    "base/TWAPOracleBase.sol",
  ],
  configureYulOptimizer: true,
  solcOptimizerDetails: {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  },
}
