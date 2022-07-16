import { expect } from "chai"
import { BigNumber } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { currentBlockchainTime, setBlockchainTime } from "./utils/time"

describe("Bonding V1", function () {
  before(async function () {
    this.EpochManager = await ethers.getContractFactory("EpochManager")
    this.BroToken = await ethers.getContractFactory("BroToken")
    this.MockPriceOracle = await ethers.getContractFactory("MockPriceOracle")
    this.BondingV1 = await ethers.getContractFactory("BondingV1")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.treasury = this.signers[1]
    this.distributor = this.signers[2]
    this.mark = this.signers[3]
  })

  beforeEach(async function () {
    this.epochManager = await this.EpochManager.deploy()
    await this.epochManager.deployed()

    this.broToken = await this.BroToken.deploy(this.distributor.address)
    await this.broToken.deployed()

    this.wAvax = await this.BroToken.deploy(this.mark.address)
    await this.wAvax.deployed()

    this.teslaToken = await this.BroToken.deploy(this.mark.address)
    await this.teslaToken.deployed()

    this.wEth = await this.BroToken.deploy(this.mark.address)
    await this.wEth.deployed()

    this.mockPriceOracle = await this.MockPriceOracle.deploy()
    await this.mockPriceOracle.deployed()

    this.bonding = await upgrades.deployProxy(this.BondingV1, [
      this.epochManager.address,
      this.broToken.address,
      this.treasury.address,
      this.distributor.address,
      100,
    ])
    await this.bonding.deployed()
  })

  it("should allow only owner to properly modify bonding options", async function () {
    // add
    await expect(
      this.bonding.addBondOption(this.broToken.address, this.mockPriceOracle.address, 100)
    ).to.be.revertedWith("Wrong discount precision")
    await expect(this.bonding.addBondOption(this.broToken.address, this.mockPriceOracle.address, 5)).to.be.revertedWith(
      "Forbidden to bond against BRO Token"
    )

    await this.bonding.addBondOption(this.wAvax.address, this.mockPriceOracle.address, 5)
    await expect(this.bonding.addBondOption(this.wAvax.address, this.mockPriceOracle.address, 5)).to.be.revertedWith(
      "Bond option already exists"
    )

    var bondOptions = await this.bonding.getBondOptions()
    expect(bondOptions.length).to.equal(1)
    expect(bondOptions[0].enabled).to.equal(true)
    expect(bondOptions[0].token).to.equal(this.wAvax.address)
    expect(bondOptions[0].oracle).to.equal(this.mockPriceOracle.address)
    expect(bondOptions[0].discount).to.equal(105)
    expect(bondOptions[0].bondingBalance).to.equal(BigNumber.from("0"))

    // enable/disable
    await expect(this.bonding.enableBondOption(this.wAvax.address)).to.be.revertedWith("Bonding option already enabled")
    await expect(this.bonding.disableBondOption(this.wAvax.address)).to.be.revertedWith(
      "One or more bonding options should always be enabled"
    )

    await this.bonding.addBondOption(this.teslaToken.address, this.mockPriceOracle.address, 5)

    await this.bonding.disableBondOption(this.wAvax.address)
    expect((await this.bonding.getBondOptions())[0].enabled).to.equal(false)

    await expect(this.bonding.disableBondOption(this.wAvax.address)).to.be.revertedWith(
      "Bonding option already disabled"
    )

    await this.bonding.enableBondOption(this.wAvax.address)
    expect((await this.bonding.getBondOptions())[0].enabled).to.equal(true)

    await this.bonding.removeBondOption(this.teslaToken.address)
    await expect(this.bonding.enableBondOption(this.teslaToken.address)).to.be.revertedWith(
      "Bonding option doesn't exists"
    )
    await expect(this.bonding.disableBondOption(this.teslaToken.address)).to.be.revertedWith(
      "Bonding option doesn't exists"
    )

    // update discount
    await expect(this.bonding.updateBondDiscount(this.wAvax.address, 101)).to.be.revertedWith(
      "Wrong discount precision"
    )
    await expect(this.bonding.updateBondDiscount(this.teslaToken.address, 10)).to.be.revertedWith(
      "Bonding option doesn't exists"
    )

    await this.bonding.updateBondDiscount(this.wAvax.address, 10)
    expect((await this.bonding.getBondOptions())[0].discount).to.equal(110)

    // remove
    // distribute to test transfer case
    await this.broToken
      .connect(this.distributor)
      .transfer(this.bonding.address, 100, { from: this.distributor.address })
    await this.bonding.connect(this.distributor).handleDistribution(100, { from: this.distributor.address })
    await this.bonding.addBondOption(this.teslaToken.address, this.mockPriceOracle.address, 5)
    expect(await this.bonding.getDisabledBondOptionsCount()).to.equal(0)
    expect((await this.bonding.getBondOptions())[0].bondingBalance).to.equal(BigNumber.from("100"))
    expect((await this.bonding.getBondOptions())[1].bondingBalance).to.equal(BigNumber.from("0"))
    expect(await this.broToken.balanceOf(this.bonding.address)).to.equal(100)

    await expect(this.bonding.removeBondOption(this.broToken.address)).to.be.revertedWith(
      "Bonding option doesn't exists"
    )

    await this.bonding.removeBondOption(this.teslaToken.address)
    expect((await this.bonding.getBondOptions()).length).to.equal(1)

    await this.bonding.removeBondOption(this.wAvax.address)
    expect((await this.bonding.getBondOptions()).length).to.equal(0)
    expect(await this.broToken.balanceOf(this.bonding.address)).to.equal(0)

    // onlyOwner checks
    await expect(
      this.bonding.connect(this.mark).enableBondOption(this.wAvax.address, { from: this.mark.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
    await expect(
      this.bonding.connect(this.mark).disableBondOption(this.wAvax.address, { from: this.mark.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
    await expect(
      this.bonding
        .connect(this.mark)
        .addBondOption(this.wAvax.address, this.mockPriceOracle.address, 5, { from: this.mark.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
    await expect(
      this.bonding.connect(this.mark).updateBondDiscount(this.wAvax.address, 10, { from: this.mark.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
    await expect(
      this.bonding.connect(this.mark).removeBondOption(this.wAvax.address, { from: this.mark.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should allow only owner to properly set bonding mode", async function () {
    // set normal
    await this.bonding.setNormalMode(100)
    expect(await this.bonding.getBondingMode()).to.equal(0)
    const [vestingPeriod, _addr] = await this.bonding.getModeConfig()
    expect(vestingPeriod).to.equal(BigNumber.from("100"))

    // set community
    await this.bonding.setCommunityMode(this.mark.address, 150)
    expect(await this.bonding.getBondingMode()).to.equal(1)
    const [epochsUnstake, stakingAddr] = await this.bonding.getModeConfig()
    expect(epochsUnstake).to.equal(150)
    expect(stakingAddr).to.equal(this.mark.address)

    // onlyOwner checks
    await expect(this.bonding.connect(this.mark).setNormalMode(100, { from: this.mark.address })).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(
      this.bonding.connect(this.mark).setCommunityMode(this.mark.address, 150, { from: this.mark.address })
    ).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("should properly handle distributions", async function () {
    await this.bonding.addBondOption(this.wAvax.address, this.mockPriceOracle.address, 5)

    await this.broToken
      .connect(this.distributor)
      .transfer(this.bonding.address, 100, { from: this.distributor.address })
    await this.bonding.connect(this.distributor).handleDistribution(100, { from: this.distributor.address })

    expect((await this.bonding.getBondOptions())[0].bondingBalance).to.equal(BigNumber.from("100"))

    await this.bonding.addBondOption(this.teslaToken.address, this.mockPriceOracle.address, 5)
    await this.broToken
      .connect(this.distributor)
      .transfer(this.bonding.address, 100, { from: this.distributor.address })
    await this.bonding.connect(this.distributor).handleDistribution(100, { from: this.distributor.address })

    expect((await this.bonding.getBondOptions())[0].bondingBalance).to.equal(BigNumber.from("150"))
    expect((await this.bonding.getBondOptions())[1].bondingBalance).to.equal(BigNumber.from("50"))

    await this.bonding.disableBondOption(this.teslaToken.address)
    await this.broToken
      .connect(this.distributor)
      .transfer(this.bonding.address, 100, { from: this.distributor.address })
    await this.bonding.connect(this.distributor).handleDistribution(100, { from: this.distributor.address })

    expect((await this.bonding.getBondOptions())[0].bondingBalance).to.equal(BigNumber.from("250"))
    expect((await this.bonding.getBondOptions())[1].bondingBalance).to.equal(BigNumber.from("50"))

    await this.bonding.addBondOption(this.wEth.address, this.mockPriceOracle.address, 5)
    await this.bonding.enableBondOption(this.teslaToken.address)
    await this.broToken
      .connect(this.distributor)
      .transfer(this.bonding.address, 100, { from: this.distributor.address })
    await this.bonding.connect(this.distributor).handleDistribution(100, { from: this.distributor.address })

    expect((await this.bonding.getBondOptions())[0].bondingBalance).to.equal(BigNumber.from("283"))
    expect((await this.bonding.getBondOptions())[1].bondingBalance).to.equal(BigNumber.from("83"))
    expect((await this.bonding.getBondOptions())[2].bondingBalance).to.equal(BigNumber.from("33"))

    // onlyDistributor check
    await expect(
      this.bonding.connect(this.mark).handleDistribution(150, { from: this.mark.address })
    ).to.be.revertedWith("Caller is not the distributor")
  })

  it("should properly execute bond and claim payouts", async function () {
    await this.bonding.setNormalMode(1)
    await this.bonding.addBondOption(this.wAvax.address, this.mockPriceOracle.address, 5)
    await this.bonding.addBondOption(this.teslaToken.address, this.mockPriceOracle.address, 10)
    await this.broToken
      .connect(this.distributor)
      .transfer(this.bonding.address, 10_000, { from: this.distributor.address })
    await this.bonding.connect(this.distributor).handleDistribution(10_000, { from: this.distributor.address })

    await expect(
      this.bonding.connect(this.mark).bond(this.wEth.address, 150, { from: this.mark.address })
    ).to.be.revertedWith("Bonding option doesn't exists")

    await this.wAvax.connect(this.mark).approve(this.bonding.address, 100)
    await this.bonding.connect(this.mark).bond(this.wAvax.address, 100, { from: this.mark.address })

    await this.teslaToken.connect(this.mark).approve(this.bonding.address, 500)
    await this.bonding.connect(this.mark).bond(this.teslaToken.address, 500, { from: this.mark.address })

    expect((await this.bonding.getClaims(this.mark.address)).length).to.equal(2)
    expect((await this.bonding.getClaims(this.mark.address))[0].amount).to.equal(210)
    expect((await this.bonding.getClaims(this.mark.address))[1].amount).to.equal(1100)
    expect((await this.bonding.getBondOptions())[0].bondingBalance).to.equal(BigNumber.from("4790"))
    expect((await this.bonding.getBondOptions())[1].bondingBalance).to.equal(BigNumber.from("3900"))

    await this.teslaToken.connect(this.mark).approve(this.bonding.address, 10_000)
    await expect(
      this.bonding.connect(this.mark).bond(this.teslaToken.address, 1, { from: this.mark.address })
    ).to.be.revertedWith("Bond payout is less then min bro payout")
    await expect(
      this.bonding.connect(this.mark).bond(this.teslaToken.address, 10_000, { from: this.mark.address })
    ).to.be.revertedWith("Not enough balance for payout")

    // claim
    await expect(this.bonding.connect(this.mark).claim({ from: this.mark.address })).to.be.revertedWith(
      "Nothing to claim"
    )

    const currentTime = (await currentBlockchainTime(ethers.provider)) + 86500
    await setBlockchainTime(ethers.provider, currentTime)

    await this.bonding.connect(this.mark).claim({ from: this.mark.address })
    expect(await this.broToken.balanceOf(this.mark.address)).to.equal(1310)
    expect((await this.bonding.getClaims(this.mark.address)).length).to.equal(0)

    await this.bonding.connect(this.mark).bond(this.teslaToken.address, 200, { from: this.mark.address })
    await setBlockchainTime(ethers.provider, currentTime + 50000)
    await this.bonding.connect(this.mark).bond(this.teslaToken.address, 300, { from: this.mark.address })
    await setBlockchainTime(ethers.provider, currentTime + 100_000)

    await this.bonding.connect(this.mark).claim({ from: this.mark.address })
    expect(await this.broToken.balanceOf(this.mark.address)).to.equal(1750)
    expect((await this.bonding.getClaims(this.mark.address)).length).to.equal(1)

    await setBlockchainTime(ethers.provider, currentTime + 200_000)
    await this.bonding.connect(this.mark).claim({ from: this.mark.address })
    expect(await this.broToken.balanceOf(this.mark.address)).to.equal(2410)
    expect((await this.bonding.getClaims(this.mark.address)).length).to.equal(0)
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
