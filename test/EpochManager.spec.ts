import { expect } from "chai"
import { BigNumber } from "ethers"
import { ethers, network } from "hardhat"

describe("Epoch Manager", function () {
  before(async function () {
    this.EpochManager = await ethers.getContractFactory("EpochManager")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.bobo = this.signers[1]
  })

  beforeEach(async function () {
    this.epochManager = await this.EpochManager.deploy()
    await this.epochManager.deployed()
  })

  it("should return default epoch length", async function () {
    const epoch = await this.epochManager.getEpoch()
    expect(epoch).to.equal(BigNumber.from("86400"))
  })

  it("should only allow owner to change epoch", async function () {
    await expect(
      this.epochManager.connect(this.bobo).setEpoch("150000", { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")

    await this.epochManager.connect(this.owner).setEpoch(BigNumber.from("150000"), { from: this.owner.address })
    expect(await this.epochManager.getEpoch()).to.equal(BigNumber.from("150000"))
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
