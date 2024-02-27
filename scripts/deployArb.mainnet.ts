import { run } from "hardhat"

async function verifyContract(contractAddress: string, args: any) {
  if (hre.network.name !== "hardhat")
    await run("verify:verify", { address: contractAddress, constructorArguments: args })
}

function getProdConfig() {
  return {
    broTokenOwner: "0x3ed85f0488EdF594F212c5346E7893B42EC33Af7",
    broTokenTotalSupply: "550000000000000000000000000",
    bbroTokenOwner: "0x3ed85f0488EdF594F212c5346E7893B42EC33Af7",
    bbroTokenTotalSupply: "90000000000000000000000000",
    stakingContractOwner: "0x3ed85f0488EdF594F212c5346E7893B42EC33Af7",
    initialLockedUntil: 1711324800,
    protocolMigratorContractOwner: "0x80a64edD2141118543c790A689E238cdED78e526",
  }
}

function getTestConfig() {
  return {
    broTokenOwner: "0x48762C21D2507c17c5F635F1BD3C1E917DB46199",
    broTokenTotalSupply: "1000",
    bbroTokenOwner: "0x48762C21D2507c17c5F635F1BD3C1E917DB46199",
    bbroTokenTotalSupply: "1000",
    stakingContractOwner: "0x48762C21D2507c17c5F635F1BD3C1E917DB46199",
    initialLockedUntil: 0,
    protocolMigratorContractOwner: "0x48762C21D2507c17c5F635F1BD3C1E917DB46199",
  }
}

export async function deploy() {
  const deployerAddress = (await ethers.getSigners())[0].address

  const config = getProdConfig()

  // Bro token deployment
  console.log("Deploying Bro...")
  const BroToken = await ethers.getContractFactory("BroTokenArb")
  const broArgs = ["Bro Token", "BRO", deployerAddress, config.broTokenTotalSupply, config.broTokenOwner]
  const broToken = await BroToken.deploy(...broArgs)
  const broTokenAddress = await broToken.getAddress()
  await verifyContract(broTokenAddress, broArgs)
  console.log("Bro token address: ", broTokenAddress)
  console.log("------------")

  // BBro token deployment
  console.log("Deploying BBro...")
  const BbroToken = await ethers.getContractFactory("BBroTokenArb")
  const bbroTokenArgs = ["bBRO Token", "bBRO", deployerAddress, config.bbroTokenTotalSupply, config.bbroTokenOwner]
  const bbroToken = await upgrades.deployProxy(BbroToken, bbroTokenArgs)
  const bbroTokenAddress = await bbroToken.getAddress()
  await verifyContract(bbroTokenAddress, [])
  console.log("BBro token address: ", bbroTokenAddress)
  console.log("------------")

  // Staking deployment
  console.log("Deploying staking...")
  const Staking = await ethers.getContractFactory("StakingArb")
  const staking = await upgrades.deployProxy(Staking, [broTokenAddress, config.initialLockedUntil])
  const stakingAddress = await staking.getAddress()
  await staking.transferOwnership(config.stakingContractOwner)
  await verifyContract(stakingAddress, [])
  console.log("Staking contract address: ", stakingAddress)
  console.log("------------")

  // Protocol migrator deployment
  console.log("Protocol migrator...")
  const ProtocolMigrator = await ethers.getContractFactory("ProtocolMigratorArb")
  const protocolMigratorArgs = [broTokenAddress, bbroTokenAddress, stakingAddress]
  const protocolMigrator = await ProtocolMigrator.deploy(...protocolMigratorArgs)
  const protocolMigratorAddress = await protocolMigrator.getAddress()
  await protocolMigrator.transferOwnership(config.protocolMigratorContractOwner)
  console.log("Protocol migrator contract address: ", protocolMigratorAddress)
  await verifyContract(protocolMigratorAddress, protocolMigratorArgs)
  console.log("------------")

  await broToken.transfer(protocolMigratorAddress, config.broTokenTotalSupply)
  await bbroToken.transfer(protocolMigratorAddress, config.bbroTokenTotalSupply)

  if (hre.network.name == "hardhat") {
    // migration
    let migrationData = [[deployerAddress, 1, 2, 1]]
    for (let index = 0; index < 99; index++) {
      migrationData.push([deployerAddress, 1, 2, 1])
    }
    const txReceipt = await protocolMigrator.migrate(migrationData)
    console.log("balanceOf before withdrawal: ", await staking.balanceOf(deployerAddress))
    await staking.withdraw(1)
    console.log("balance after withdrawal: ", await staking.balanceOf(deployerAddress))
    const { gasUsed } = await txReceipt.wait(1)
    console.log("Gas used: ", gasUsed)
  }
}

async function deployTestStakingContract() {
  const config = getTestConfig()
  const broTOkenAddress = "0x2b45e21C35A33C58E4C5ce82A82466b0754Fd154"

  // Staking deployment
  console.log("Deploying staking...")
  const Staking = await ethers.getContractFactory("StakingArb")
  const staking = await upgrades.deployProxy(Staking, [broTOkenAddress, config.initialLockedUntil])
  const stakingAddress = await staking.getAddress()
  await staking.transferOwnership(config.stakingContractOwner)
  await verifyContract(stakingAddress, [])
  console.log("Staking address: ", stakingAddress)
  console.log("------------")
}

deploy().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

// deployTestStakingContract().catch((error) => {
//   console.error(error)
//   process.exitCode = 1
// })
