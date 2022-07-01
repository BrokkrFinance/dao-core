import { expect } from "chai"
import { ethers, network } from "hardhat"
import { currentBlockchainTime, setBlockchainTime } from "./utils/time"

const DISTRIBUTION_DAY = 86400

describe("Token Distributor", function () {
  before(async function () {
    this.TokenDistributor = await ethers.getContractFactory("TokenDistributor")
    this.BroToken = await ethers.getContractFactory("BroToken")
    this.EpochManager = await ethers.getContractFactory("EpochManager")
    this.MockDistributionHandler = await ethers.getContractFactory("MockDistributionHandler")

    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.bobo = this.signers[1]
  })

  beforeEach(async function () {
    this.mockDistributionHandler = await this.MockDistributionHandler.deploy(true)
    await this.mockDistributionHandler.deployed()

    this.mockDistributionHandler2 = await this.MockDistributionHandler.deploy(false)
    await this.mockDistributionHandler2.deployed()

    this.broToken = await this.BroToken.deploy(this.owner.address)
    await this.broToken.deployed()

    this.epochManager = await this.EpochManager.deploy()
    await this.epochManager.deployed()

    const currentTimestamp = await currentBlockchainTime(ethers.provider)
    this.tokenDistributor = await this.TokenDistributor.deploy(
      this.broToken.address,
      this.epochManager.address,
      currentTimestamp
    )
    await this.tokenDistributor.deployed()

    await this.broToken.transfer(this.tokenDistributor.address, "10000")
  })

  it("should allow only owner to properly add/remove/update distribuitions", async function () {
    await expect(this.tokenDistributor.removeDistribution(1)).to.be.revertedWith("Out of bounds.")
    await expect(this.tokenDistributor.updateDistributionAmount(1, 10)).to.be.revertedWith("Out of bounds.")

    await expect(this.tokenDistributor.addDistribution(this.broToken.address, 10)).to.be.reverted
    await expect(this.tokenDistributor.addDistribution(this.mockDistributionHandler2.address, 10)).to.be.revertedWith(
      "Provided address doesn't support distributions."
    )

    expect(await this.tokenDistributor.perEpochDistributionAmount()).to.equal(0)
    await expect(this.tokenDistributor.addDistribution(this.mockDistributionHandler.address, 100))
      .to.emit(this.tokenDistributor, "DistributionAdded")
      .withArgs(this.mockDistributionHandler.address, 100)
    expect(await this.tokenDistributor.totalDistributions()).to.equal(1)

    const handler = await this.tokenDistributor.distributionByIndex(0)
    expect(handler.handler).to.equal(this.mockDistributionHandler.address)
    expect(handler.amount).to.equal(100)
    expect(await this.tokenDistributor.perEpochDistributionAmount()).to.equal(100)

    await expect(this.tokenDistributor.addDistribution(this.mockDistributionHandler.address, 400)).to.be.revertedWith(
      "Distribution already exists."
    )

    await expect(this.tokenDistributor.updateDistributionAmount(0, 200))
      .to.emit(this.tokenDistributor, "DistributionAmountUpdated")
      .withArgs(this.mockDistributionHandler.address, 100, 200)

    expect((await this.tokenDistributor.distributionByIndex(0)).amount).to.equal(200)
    expect(await this.tokenDistributor.perEpochDistributionAmount()).to.equal(200)

    await expect(this.tokenDistributor.removeDistribution(0))
      .to.emit(this.tokenDistributor, "DistributionRemoved")
      .withArgs(this.mockDistributionHandler.address)
    expect(await this.tokenDistributor.perEpochDistributionAmount()).to.equal(0)
    expect(await this.tokenDistributor.totalDistributions()).to.equal(0)
  })

  it("should stop distributions when paused", async function () {
    await this.tokenDistributor.pause()
    expect(await this.tokenDistributor.paused()).to.equal(true)
    await expect(this.tokenDistributor.distribute()).to.be.revertedWith("Pausable: paused")
    await this.tokenDistributor.unpause()
    expect(await this.tokenDistributor.paused()).to.equal(false)
    await expect(this.tokenDistributor.distribute()).to.be.revertedWith("Distributions is not registered.")

    await expect(this.tokenDistributor.connect(this.bobo).pause({ from: this.bobo.address })).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.tokenDistributor.connect(this.bobo).unpause({ from: this.bobo.address })).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
  })

  it("should properly distribute tokens to contracts", async function () {
    expect(await this.broToken.balanceOf(this.tokenDistributor.address)).to.equal(10000)
    expect(await this.broToken.balanceOf(this.mockDistributionHandler.address)).to.equal(0)
    expect(await this.mockDistributionHandler.getCounter()).to.equal(0)

    await this.tokenDistributor.addDistribution(this.mockDistributionHandler.address, 100)
    expect(await this.tokenDistributor.isReadyForDistribution()).to.equal(false)
    await expect(this.tokenDistributor.distribute()).to.be.revertedWith("Nothing to distribute.")

    const currentTime = (await currentBlockchainTime(ethers.provider)) + DISTRIBUTION_DAY + 1
    await setBlockchainTime(ethers.provider, currentTime)
    expect(await this.tokenDistributor.isReadyForDistribution()).to.equal(true)

    await expect(this.tokenDistributor.distribute())
      .to.emit(this.tokenDistributor, "DistributionTriggered")
      .withArgs(100)
    expect(await this.broToken.balanceOf(this.tokenDistributor.address)).to.equal(9900)
    expect(await this.broToken.balanceOf(this.mockDistributionHandler.address)).to.equal(100)
    expect(await this.mockDistributionHandler.getCounter()).to.equal(1)
    expect(await this.tokenDistributor.isReadyForDistribution()).to.equal(false)

    await this.tokenDistributor.updateDistributionAmount(0, 10000)
    await setBlockchainTime(ethers.provider, currentTime + DISTRIBUTION_DAY + 1)
    await expect(this.tokenDistributor.distribute()).to.be.revertedWith("Not enough tokens for distribution.")
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
