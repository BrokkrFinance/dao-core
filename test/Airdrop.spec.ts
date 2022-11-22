import { expect } from "chai"
import { BigNumber } from "ethers"
import { ethers, network } from "hardhat"
import { currentBlockchainTime, setBlockchainTime } from "./utils/time"

const stage1Root = "0x33095a3ee49a44f2121cfa463a55b044476c5e4a498796532b19dc34c4c8d5ab"
const stage1Proofs = [
  ["0x2ceccebe71d3406fcf430a74fd1fc7e2977f3b51b83304094afc8773d7ca5380"],
  ["0x60b804e11554b6c0d72577a181152f1554fd18169d7919971a6f80cd51eccb58"],
]

describe("Airdrop", function () {
  before(async function () {
    this.Airdrop = await ethers.getContractFactory("Airdrop")
    this.BroToken = await ethers.getContractFactory("BroToken")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.mark = this.signers[1]
    this.paul = this.signers[2]
    this.withdrawal = this.signers[3]
  })

  beforeEach(async function () {
    this.broToken = await this.BroToken.deploy("Bro Token", "$BRO", this.owner.address)
    await this.broToken.deployed()

    this.airdrop = await this.Airdrop.deploy(this.broToken.address, this.withdrawal.address)
    await this.airdrop.deployed()

    await this.broToken.approve(this.airdrop.address, "100000000")
  })

  it("should allow only owner to register merkle root", async function () {
    const claimableUntil = (await currentBlockchainTime(ethers.provider)) + 86400

    expect(await this.airdrop.latestStage()).to.equal(0)
    await this.airdrop.registerMerkleRoot("1000", stage1Root, claimableUntil)
    expect(await this.airdrop.latestStage()).to.equal(1)
    expect((await this.airdrop.claimStage(1)).merkleRoot).to.equal(stage1Root)
    expect((await this.airdrop.claimStage(1)).claimableUntil).to.equal(claimableUntil)
    expect(await this.airdrop.canClaimStage(1)).to.equal(true)

    await expect(
      this.airdrop
        .connect(this.mark)
        .registerMerkleRoot("1000", stage1Root, claimableUntil, { from: this.mark.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should properly claim airdrop rewards", async function () {
    let claimableUntil = (await currentBlockchainTime(ethers.provider)) + 86400

    await this.airdrop.registerMerkleRoot("700", stage1Root, claimableUntil)
    expect(await this.airdrop.latestStage()).to.equal(1)

    expect(await this.airdrop.isClaimed(this.mark.address, 1)).to.equal(false)
    expect(await this.airdrop.isClaimed(this.paul.address, 1)).to.equal(false)
    expect((await this.airdrop.claimStage(1)).merkleRoot).to.equal(stage1Root)

    await expect(
      this.airdrop.connect(this.mark).claim(1, stage1Proofs[1], "300", { from: this.mark.address })
    ).to.be.revertedWith("Invalid Merkle Proof.")

    await this.airdrop.connect(this.mark).claim(1, stage1Proofs[0], "300", { from: this.mark.address })
    expect(await this.airdrop.isClaimed(this.mark.address, 1)).to.equal(true)
    expect(await this.broToken.balanceOf(this.mark.address)).to.equal(300)

    await this.airdrop.connect(this.paul).claim(1, stage1Proofs[1], "400", { from: this.paul.address })
    expect(await this.airdrop.isClaimed(this.paul.address, 1)).to.equal(true)
    expect(await this.broToken.balanceOf(this.paul.address)).to.equal(400)

    expect(await this.airdrop.getClaimedBroPerStage(1)).to.eq(700)
    expect(await this.airdrop.getClaimedAccountsCountPerStage(1)).to.eq(2)

    await expect(
      this.airdrop.connect(this.mark).claim(1, stage1Proofs[0], "300", { from: this.mark.address })
    ).to.be.revertedWith("Reward already claimed.")
  })

  it("should block claims after stage expired", async function () {
    let claimableUntil = (await currentBlockchainTime(ethers.provider)) + 86400

    await this.airdrop.registerMerkleRoot("700", stage1Root, claimableUntil)
    expect(await this.airdrop.canClaimStage(1)).to.equal(true)

    await setBlockchainTime(ethers.provider, claimableUntil + 1)

    expect(await this.airdrop.canClaimStage(1)).to.equal(false)
    await expect(
      this.airdrop.connect(this.mark).claim(1, stage1Proofs[0], "300", { from: this.mark.address })
    ).to.be.revertedWith("Claimable period is over.")

    const withdrawAccountBalanceBefore = await this.broToken.balanceOf(this.withdrawal.address)

    await expect(this.airdrop.connect(this.mark).withdrawRemainings()).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )

    await this.airdrop.withdrawRemainings()

    const withdrawAccountBalanceAfter = await this.broToken.balanceOf(this.withdrawal.address)
    expect(withdrawAccountBalanceAfter.sub(withdrawAccountBalanceBefore)).to.equal(BigNumber.from("700"))
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
