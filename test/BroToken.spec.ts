import { expect } from "chai"
import { ethers, network } from "hardhat"

describe("Bro Token", function () {
  before(async function () {
    this.BroToken = await ethers.getContractFactory("BroToken")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.mark = this.signers[1]
  })

  beforeEach(async function () {
    this.broToken = await this.BroToken.deploy("Bro Token", "$BRO", this.owner.address)
    await this.broToken.deployed()
  })

  it("should allow only owner to set name/symbol", async function () {
    expect(await this.broToken.name()).to.equal("Bro Token")
    expect(await this.broToken.symbol()).to.equal("$BRO")

    await this.broToken.setName("Bro Token Reborn")
    await this.broToken.setSymbol("$BROR")

    expect(await this.broToken.name()).to.equal("Bro Token Reborn")
    expect(await this.broToken.symbol()).to.equal("$BROR")

    await expect(this.broToken.connect(this.mark).setName("Some")).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.broToken.connect(this.mark).setSymbol("Some")).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
