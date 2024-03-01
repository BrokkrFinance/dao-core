import * as fs from "fs"
import { ethers } from "hardhat"
const { MerkleTree } = require("merkletreejs")

interface IAccount {
  address: string
  amount: string
}

interface IAirdropResult {
  stage: number
  merkleRoot: string
  userProofs: {
    address: string
    proof: string[]
  }[]
}

function getTree(whitelistedAddresses: IAccount[]) {
  const leafs = whitelistedAddresses.map((account: IAccount) =>
    ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [account.address, account.amount]))
  )
  return new MerkleTree(leafs, ethers.utils.keccak256, { sort: true })
}

function getMerkleRoot(tree: any) {
  return tree.getHexRoot()
}

function getMerkleProof(tree: any, account: IAccount) {
  return tree.getHexProof(
    ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [account.address, account.amount]))
  )
}

async function main() {
  const users: IAccount[] = JSON.parse(fs.readFileSync("./scripts/merkle/airdrop.json", "utf8"))

  const tree = getTree(users)

  const airdropResult: IAirdropResult = {
    stage: 1,
    merkleRoot: getMerkleRoot(tree),
    userProofs: [],
  }

  for (const user of users) {
    const userProof = getMerkleProof(tree, user)
    airdropResult.userProofs.push({
      address: user.address,
      proof: userProof,
    })
  }

  fs.writeFileSync(`./scripts/merkle/${airdropResult.stage}-userProofs.json`, JSON.stringify(airdropResult, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
