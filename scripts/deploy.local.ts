import { deploy } from "./deployer"

async function main() {
  await deploy("testnet", "local")
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
