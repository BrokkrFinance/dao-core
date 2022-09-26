import { ethers } from "hardhat"

async function main() {
  const ProtocolMigrator = await ethers.getContractFactory("ProtocolMigrator")
  const protocolMigrator = await ProtocolMigrator.deploy(
    "0x65031e28Cb0E8CC21Ae411f9dD22c9b1bd260Ce4",
    "0x53d8FEde675825db0fCA6FF3e25D46b7510e8c8b",
    "0xa3a54fe9231D61D7Afa57c92DB6B669f86a33EBd",
    14
  )
  await protocolMigrator.deployed()

  await protocolMigrator.transferOwnership("0xDE971dAc0009Dfb373AcEE32F94777AF2E38e56C")

  console.log(`New Protocol migrator: ${protocolMigrator.address}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
