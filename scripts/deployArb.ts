import { run } from "hardhat"
import { readConfig } from "./utils"

async function verifyContract(contractAddress: string, args: any) {
  if (hre.network.name !== "hardhat")
    await run("verify:verify", { address: contractAddress, constructorArguments: args })
}

export async function deploy() {
  const deployerAddress = (await ethers.getSigners())[0].address

  const config = readConfig("mainnetArbDao")

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

async function deployContract(contractName: string, constructorArgs: any[]): any {
  console.log("Deploying ", contractName, "...")
  const ContractFactory = await ethers.getContractFactory(contractName)

  const contract = await ContractFactory.deploy(...constructorArgs)
  const contractAddress = await contract.getAddress()
  await verifyContract(contractAddress, constructorArgs)
  console.log(contractName, " address: ", contractAddress)
  console.log("------------")
  return contract
}

async function deployMerkleReward() {
  const merkleRewardConfig = readConfig("mainnetArbMerkl")

  const merkleReward = await deployContract("MerkleReward", [
    merkleRewardConfig.rewardToken,
    merkleRewardConfig.admin,
    merkleRewardConfig.merkleRootUpdater,
    merkleRewardConfig.pauser,
  ])

  if (hre.network.name == "hardhat") {
    await merkleReward.registerMerkleRoot("0x34f56aaad956c17bd71ba99d255c489e4208483fe1aaf6182833f3c1fd097aa0")
    console.log("root:", await merkleReward.root())
    await merkleReward.claim(
      [
        "0x603ebc0e555e20c1c652b3f4cbfe6f2ecf75b218cfee015568155d5bc51372a4",
        "0xd728440a1ca7bcdfbf5a6f529c3d912abf409aca9cb22cf108adffcc5ef8a56b",
      ],
      "0x2222222222222222222222222222222222222222",
      22
    )
  }
}

// deploy().catch((error) => {
//   console.error(error)
//   process.exitCode = 1
// })

deployMerkleReward().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
