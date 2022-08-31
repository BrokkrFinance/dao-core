import { expect } from "chai"
import { ethers, network, upgrades } from "hardhat"

describe("bBRO Token", function () {
  before(async function () {
    this.BBroToken = await ethers.getContractFactory("BBroToken")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.bobo = this.signers[1]
    this.mark = this.signers[2]
  })

  beforeEach(async function () {
    this.bbroToken = await upgrades.deployProxy(this.BBroToken, ["bBRO Token", "bBRO"])
    await this.bbroToken.deployed()
  })

  it("should allow only owner to set name/symbol", async function () {
    expect(await this.bbroToken.name()).to.equal("bBRO Token")
    expect(await this.bbroToken.symbol()).to.equal("bBRO")

    await this.bbroToken.setName("bBro Token Reborn")
    await this.bbroToken.setSymbol("$bBROR")

    expect(await this.bbroToken.name()).to.equal("bBro Token Reborn")
    expect(await this.bbroToken.symbol()).to.equal("$bBROR")

    await expect(this.bbroToken.connect(this.mark).setName("Some")).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.bbroToken.connect(this.mark).setSymbol("Some")).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
  })

  it("should only allow owner to whitelist/remove address", async function () {
    expect(await this.bbroToken.isWhitelisted(this.mark.address)).to.equal(false)
    await this.bbroToken.whitelistAddress(this.mark.address)
    expect(await this.bbroToken.isWhitelisted(this.mark.address)).to.equal(true)
    await this.bbroToken.removeWhitelisted(this.mark.address)
    expect(await this.bbroToken.isWhitelisted(this.mark.address)).to.equal(false)
  })

  it("should only allow whitelisted account to mint tokens", async function () {
    await this.bbroToken.whitelistAddress(this.mark.address)
    await this.bbroToken.connect(this.mark).mint(this.bobo.address, "1000", { from: this.mark.address })

    expect(await this.bbroToken.balanceOf(this.bobo.address)).to.equal("1000")

    await expect(
      this.bbroToken.connect(this.bobo).mint(this.mark.address, "100000", { from: this.bobo.address })
    ).to.be.revertedWith("Address is not whitelisted.")
  })

  it("should always revert on transfer and transferFrom", async function () {
    await expect(this.bbroToken.transfer(this.mark.address, "100000")).to.be.revertedWith("Transfer is disabled.")
    await expect(this.bbroToken.transferFrom(this.mark.address, this.bobo.address, "100000")).to.be.revertedWith(
      "TransferFrom is disabled."
    )
  })

  it("should allow to burn tokens", async function () {
    await this.bbroToken.whitelistAddress(this.mark.address)
    await this.bbroToken.connect(this.mark).mint(this.bobo.address, "1000", { from: this.mark.address })

    expect(await this.bbroToken.totalSupply()).to.equal("1000")

    await this.bbroToken.connect(this.bobo).burn("500", { from: this.bobo.address })
    expect(await this.bbroToken.balanceOf(this.bobo.address)).to.equal("500")
    expect(await this.bbroToken.totalSupply()).to.equal("500")
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
