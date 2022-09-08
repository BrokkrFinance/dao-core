import { deploy } from "./deployer"

async function main() {
  await deploy("testnet", "testnet")
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
