import { expect } from "chai"
import { ethers, network } from "hardhat"

const dummyIncrementEncoded = "0xd09de08a"

describe("Treasury", function () {
  before(async function () {
    this.Treasury = await ethers.getContractFactory("Treasury")
    this.BroToken = await ethers.getContractFactory("BroToken")
    this.Dummy = await ethers.getContractFactory("Dummy")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.bobo = this.signers[1]
  })

  beforeEach(async function () {
    this.broToken = await this.BroToken.deploy(this.owner.address)
    await this.broToken.deployed()

    this.anotherToken = await this.BroToken.deploy(this.owner.address)
    await this.anotherToken.deployed()

    this.treasury = await this.Treasury.deploy([this.broToken.address])
    await this.treasury.deployed()

    await this.broToken.transfer(this.treasury.address, "1000000000")
    await this.owner.sendTransaction({
      to: this.treasury.address,
      value: ethers.utils.parseEther("1.0"),
    })

    this.dummy = await this.Dummy.deploy()
    await this.dummy.deployed()
  })

  it("should allow only owner to whitelist/remove tokens", async function () {
    expect(await this.treasury.balanceOf(this.broToken.address)).to.equal(1000000000)
    expect(await this.treasury.nativeBalance()).to.equal("1000000000000000000")
    expect(await this.treasury.isTokenWhitelisted(this.broToken.address)).to.equal(true)
    expect(await this.treasury.isTokenWhitelisted(this.anotherToken.address)).to.equal(false)

    await this.treasury.whitelistTokens([this.anotherToken.address])
    await this.treasury.removeWhitelisted([this.broToken.address])
    expect(await this.treasury.isTokenWhitelisted(this.broToken.address)).to.equal(false)
    expect(await this.treasury.isTokenWhitelisted(this.anotherToken.address)).to.equal(true)

    await expect(
      this.treasury.connect(this.bobo).whitelistTokens([this.anotherToken.address], { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
    await expect(
      this.treasury.connect(this.bobo).removeWhitelisted([this.broToken.address], { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should properly execute erc20.transfer", async function () {
    expect(await this.broToken.balanceOf(this.dummy.address)).to.equal(0)
    await this.treasury.tokenTransfer(this.broToken.address, this.dummy.address, 100)
    expect(await this.broToken.balanceOf(this.dummy.address)).to.equal(100)

    await expect(this.treasury.tokenTransfer(this.anotherToken.address, this.dummy.address, 100)).to.be.revertedWith(
      "Token is not whitelisted"
    )
    await expect(
      this.treasury
        .connect(this.bobo)
        .tokenTransfer(this.broToken.address, this.dummy.address, 100, { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should properly execute erc20.transfer and call the contract", async function () {
    expect(await this.broToken.balanceOf(this.dummy.address)).to.equal(0)
    expect(await this.dummy.getVariable()).to.equal(0)
    await this.treasury.tokenTransferWithCall(this.broToken.address, this.dummy.address, 100, dummyIncrementEncoded)
    expect(await this.broToken.balanceOf(this.dummy.address)).to.equal(100)
    expect(await this.dummy.getVariable()).to.equal(1)

    await expect(
      this.treasury.tokenTransferWithCall(this.anotherToken.address, this.dummy.address, 100, dummyIncrementEncoded)
    ).to.be.revertedWith("Token is not whitelisted")
    await expect(
      this.treasury
        .connect(this.bobo)
        .tokenTransferWithCall(this.broToken.address, this.dummy.address, 100, dummyIncrementEncoded, {
          from: this.bobo.address,
        })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should properly send eth", async function () {
    expect(await ethers.provider.getBalance(this.dummy.address)).to.equal(0)
    await this.treasury.nativeTransfer(this.dummy.address, 100)
    expect(await ethers.provider.getBalance(this.dummy.address)).to.equal(100)

    await expect(
      this.treasury.connect(this.bobo).nativeTransfer(this.dummy.address, 100, { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should properly send eth and call the contract", async function () {
    expect(await ethers.provider.getBalance(this.dummy.address)).to.equal(0)
    expect(await this.dummy.getVariable()).to.equal(0)
    await this.treasury.nativeTransferWithCall(this.dummy.address, 100, dummyIncrementEncoded)
    expect(await ethers.provider.getBalance(this.dummy.address)).to.equal(100)
    expect(await this.dummy.getVariable()).to.equal(1)

    await expect(
      this.treasury
        .connect(this.bobo)
        .nativeTransferWithCall(this.dummy.address, 100, dummyIncrementEncoded, { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
