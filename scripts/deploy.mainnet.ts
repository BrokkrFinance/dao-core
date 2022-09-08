import { deploy } from "./deployer"

async function main() {
  await deploy("mainnet", "mainnet")
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
