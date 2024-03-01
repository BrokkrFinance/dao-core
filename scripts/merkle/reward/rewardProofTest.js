//import { StandardMerkleTree } from "@openzeppelin/merkle-tree"

async function main() {
  var merkle = await import("@openzeppelin/merkle-tree")

  // Building the tree
  const values = [
    ["0x1111111111111111111111111111111111111111", "11"],
    ["0x2222222222222222222222222222222222222222", "22"],
    ["0x3333333333333333333333333333333333333333", "33"],
    ["0x4444444444444444444444444444444444444444", "44"],
    ["0x5555555555555555555555555555555555555555", "55"],
  ]
  const tree = merkle.StandardMerkleTree.of(values, ["address", "uint256"])
  console.log("tree root: ", tree.root)

  // Generating proof
  for (const [i, v] of tree.entries()) {
    if (v[0] === "0x2222222222222222222222222222222222222222") {
      const proof = tree.getProof(i)
      console.log("Value:", v)
      console.log("Proof:", proof)
    }
  }
}

main()
  .then(() => {})
  .catch((err) => {
    console.log(err)
    exit(1)
  })
