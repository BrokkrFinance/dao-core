async function main() {
  console.log("Nothing")
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
