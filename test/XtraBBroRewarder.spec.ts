import { expect } from "chai"
import { ethers, network, upgrades } from "hardhat"
import { currentBlockchainTime, setBlockchainTime } from "./utils/time"

describe("XtraBBroRewarder", function () {
  before(async function () {
    this.BBroToken = await ethers.getContractFactory("BBroToken")
    this.MockStakingV1 = await ethers.getContractFactory("MockStakingV1")
    this.XtraBBroRewarder = await ethers.getContractFactory("XtraBBroRewarder")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.mark = this.signers[1]
    this.paul = this.signers[2]
  })

  beforeEach(async function () {
    this.bbroToken = await upgrades.deployProxy(this.BBroToken, ["bBRO Token", "bBRO"])
    await this.bbroToken.deployed()

    this.mockStaking = await this.MockStakingV1.deploy()
    await this.mockStaking.deployed()
    await this.mockStaking.feedMockStakers(this.mark.address, this.paul.address)

    this.rewards = await this.XtraBBroRewarder.deploy(
      this.bbroToken.address,
      this.mockStaking.address,
      (await currentBlockchainTime(ethers.provider)) + 86400,
      300,
      3000,
      10,
      30,
      5
    )
    await this.rewards.deployed()

    await this.bbroToken.whitelistAddress(this.rewards.address)
  })

  it("should allow to claim reward only for elligible stakers", async function () {
    expect((await this.rewards.availableBBroAmountToClaim(this.mark.address)).toString().substring(0, 8)).to.equal(
      "96786986"
    )
    expect(await this.rewards.availableBBroAmountToClaim(this.paul.address)).to.equal(0)
    expect(await this.rewards.isClaimed(this.mark.address)).to.equal(false)

    await this.rewards.connect(this.mark).claim()
    expect(await this.rewards.isClaimed(this.mark.address)).to.equal(true)

    await expect(this.rewards.connect(this.paul).claim()).to.be.revertedWith("Nothing to claim")
    await expect(this.rewards.connect(this.mark).claim()).to.be.revertedWith("Xtra reward already claimed")

    const currentTime = (await currentBlockchainTime(ethers.provider)) + 86500 * 2
    await setBlockchainTime(ethers.provider, currentTime)

    await expect(this.rewards.connect(this.paul).claim()).to.be.revertedWith("Xtra rewards event is over")
  })

  it("should allow whitelisted accounts to claim with extra perc", async function () {
    expect((await this.rewards.availableBBroAmountToClaim(this.mark.address)).toString().substring(0, 8)).to.equal(
      "96786986"
    )
    expect(await this.rewards.availableBBroAmountToClaim(this.paul.address)).to.equal(0)
    expect(await this.rewards.isWhitelisted(this.mark.address)).to.equal(false)

    // whitelist
    await this.rewards.batchWhitelistTerraMigrators([this.mark.address, this.paul.address])

    expect(await this.rewards.isWhitelisted(this.mark.address)).to.equal(true)
    expect(await this.rewards.isWhitelisted(this.paul.address)).to.equal(true)
    expect((await this.rewards.availableBBroAmountToClaim(this.mark.address)).toString().substring(0, 8)).to.equal(
      "10162633"
    ) // 5% increase
    expect(await this.rewards.availableBBroAmountToClaim(this.paul.address)).to.equal(0)

    await this.rewards.connect(this.mark).claim()
    expect((await this.bbroToken.balanceOf(this.mark.address)).toString().substring(0, 8)).to.equal("10162633")
    expect(await this.rewards.isClaimed(this.mark.address)).to.equal(true)
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
