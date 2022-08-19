import { expect } from "chai"
import { ethers, network } from "hardhat"
import { currentBlockchainTime, setBlockchainTime } from "./utils/time"

describe("Vesting", function () {
  before(async function () {
    this.Vesting = await ethers.getContractFactory("Vesting")
    this.BroToken = await ethers.getContractFactory("BroToken")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.bobo = this.signers[1]
  })

  beforeEach(async function () {
    this.broToken = await this.BroToken.deploy(this.owner.address)
    await this.broToken.deployed()

    this.vesting = await this.Vesting.deploy(this.broToken.address)
    await this.vesting.deployed()

    await this.broToken.transfer(this.vesting.address, "1000000000")
  })

  it("should allow only owner to register and remove vesting schedules", async function () {
    const accounts = [this.bobo.address]
    const schedules = [[[100, 100]]]

    await this.vesting.registerSchedules(accounts, schedules)
    expect(await this.vesting.claimableAmount(this.bobo.address)).to.equal(100)

    var vestingInfo = await this.vesting.vestingInfo(this.bobo.address)
    expect(vestingInfo.schedules.length).to.equal(1)
    expect(vestingInfo.schedules[0].endTime).to.equal(100)
    expect(vestingInfo.schedules[0].broAmount).to.equal(100)

    await this.vesting.removeAccount(this.bobo.address)
    expect(await this.vesting.claimableAmount(this.bobo.address)).to.equal(0)

    await expect(
      this.vesting.connect(this.bobo).registerSchedules(accounts, schedules, { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
    await expect(
      this.vesting.connect(this.bobo).removeAccount(this.bobo.address, { from: this.bobo.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should properly claim rewards", async function () {
    const currentTimestamp = await currentBlockchainTime(ethers.provider)
    const accounts = [this.bobo.address]
    const schedules = [
      [
        [currentTimestamp - 1000, 100],
        [currentTimestamp, 200],
        [currentTimestamp + (currentTimestamp - 1), 500],
      ],
    ]

    await this.vesting.registerSchedules(accounts, schedules)
    await setBlockchainTime(ethers.provider, currentTimestamp + 1000)

    expect(await this.vesting.claimableAmount(this.bobo.address)).to.equal(300)
    await this.vesting.connect(this.bobo).claim({ from: this.bobo.address })
    expect(await this.vesting.claimableAmount(this.bobo.address)).to.equal(0)
    expect(await this.broToken.balanceOf(this.bobo.address)).to.equal(300)

    await setBlockchainTime(ethers.provider, currentTimestamp * 2)
    expect(await this.vesting.claimableAmount(this.bobo.address)).to.equal(500)
    await this.vesting.connect(this.bobo).claim({ from: this.bobo.address })
    expect(await this.vesting.claimableAmount(this.bobo.address)).to.equal(0)
    expect(await this.broToken.balanceOf(this.bobo.address)).to.equal(800)
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
