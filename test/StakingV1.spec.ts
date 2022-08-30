import { expect } from "chai"
import { BigNumber } from "ethers"
import { ethers, network, upgrades } from "hardhat"
import { currentBlockchainTime, setBlockchainTime } from "./utils/time"

const STAKING_CONFIG = {
  minBroStakeAmount: ethers.utils.parseEther("1"),
  minUnstakingPeriod: 14,
  maxUnstakingPeriod: 365,
  maxUnstakingPeriodsPerStaker: 5,
  maxWithdrawalsPerUnstakingPeriod: 6,
  rewardGeneratingAmountBaseIndex: 7400,
  withdrawalAmountReducePerc: 90,
  withdrawnBBroRewardReducePerc: 50,
  bBroRewardsBaseIndex: 3000,
  bBroRewardsXtraMultiplier: 10,
}

describe("Staking V1", function () {
  before(async function () {
    this.EpochManager = await ethers.getContractFactory("EpochManager")
    this.BroToken = await ethers.getContractFactory("BroToken")
    this.BBroToken = await ethers.getContractFactory("BBroToken")
    this.Staking = await ethers.getContractFactory("StakingV1")
    this.signers = await ethers.getSigners()
    this.owner = this.signers[0]
    this.distributor = this.signers[1]
    this.communityBonding = this.signers[2]
    this.bobo = this.signers[3]
    this.mark = this.signers[4]
    this.paul = this.signers[5]
  })

  beforeEach(async function () {
    this.epochManager = await this.EpochManager.deploy()
    await this.epochManager.deployed()

    this.broToken = await this.BroToken.deploy("Bro Token", "$BRO", this.owner.address)
    await this.broToken.deployed()

    this.bbroToken = await upgrades.deployProxy(this.BBroToken, ["bBRO Token", "bBRO"])
    await this.bbroToken.deployed()

    this.staking = await upgrades.deployProxy(this.Staking, [
      [
        this.distributor.address,
        this.epochManager.address,
        this.broToken.address,
        this.bbroToken.address,
        [this.communityBonding.address],
        STAKING_CONFIG.minBroStakeAmount,
        STAKING_CONFIG.minUnstakingPeriod,
        STAKING_CONFIG.maxUnstakingPeriod,
        STAKING_CONFIG.maxUnstakingPeriodsPerStaker,
        STAKING_CONFIG.maxWithdrawalsPerUnstakingPeriod,
        STAKING_CONFIG.rewardGeneratingAmountBaseIndex,
        STAKING_CONFIG.withdrawalAmountReducePerc,
        STAKING_CONFIG.withdrawnBBroRewardReducePerc,
        STAKING_CONFIG.bBroRewardsBaseIndex,
        STAKING_CONFIG.bBroRewardsXtraMultiplier,
      ],
    ])
    await this.staking.deployed()

    await this.bbroToken.whitelistAddress(this.staking.address)

    await this.broToken.transfer(this.distributor.address, ethers.utils.parseEther("1000"))
    await this.broToken.transfer(this.communityBonding.address, ethers.utils.parseEther("1000"))
    await this.broToken.transfer(this.bobo.address, ethers.utils.parseEther("1000"))
    await this.broToken.transfer(this.mark.address, ethers.utils.parseEther("1000"))
    await this.broToken.transfer(this.paul.address, ethers.utils.parseEther("1000"))
  })

  it("should allow only owner to properly modify config", async function () {
    expect(await this.staking.distributor()).to.equal(this.distributor.address)
    expect(await this.staking.epochManager()).to.equal(this.epochManager.address)
    expect(await this.staking.broToken()).to.equal(this.broToken.address)
    expect(await this.staking.bBroToken()).to.equal(this.bbroToken.address)
    expect(await this.staking.protocolMembers(0)).to.equal(this.communityBonding.address)
    await expect(this.staking.protocolMembers(1)).to.be.reverted
    expect(await this.staking.minBroStakeAmount()).to.equal(STAKING_CONFIG.minBroStakeAmount)
    expect(await this.staking.minUnstakingPeriod()).to.equal(STAKING_CONFIG.minUnstakingPeriod)
    expect(await this.staking.maxUnstakingPeriod()).to.equal(STAKING_CONFIG.maxUnstakingPeriod)
    expect(await this.staking.maxUnstakingPeriodsPerStaker()).to.equal(STAKING_CONFIG.maxUnstakingPeriodsPerStaker)
    expect(await this.staking.maxWithdrawalsPerUnstakingPeriod()).to.equal(
      STAKING_CONFIG.maxWithdrawalsPerUnstakingPeriod
    )
    expect(await this.staking.rewardGeneratingAmountBaseIndex()).to.equal(BigNumber.from("740000000000000000"))
    expect(await this.staking.withdrawalAmountReducePerc()).to.equal(STAKING_CONFIG.withdrawalAmountReducePerc)
    expect(await this.staking.withdrawnBBroRewardReducePerc()).to.equal(STAKING_CONFIG.withdrawnBBroRewardReducePerc)
    expect(await this.staking.bBroRewardsBaseIndex()).to.equal(BigNumber.from("300000000000000000"))
    expect(await this.staking.bBroRewardsXtraMultiplier()).to.equal(STAKING_CONFIG.bBroRewardsXtraMultiplier)
    expect(await this.staking.supportsDistributions()).to.equal(true)

    await this.staking.setDistributor(this.mark.address)
    await this.staking.setMinBroStakeAmount(ethers.utils.parseEther("2"))
    await this.staking.setMinUnstakingPeriod(15)
    await this.staking.setMaxUnstakingPeriod(364)
    await this.staking.setMaxUnstakingPeriodsPerStaker(10)
    await this.staking.setMaxWithdrawalsPerUnstakingPeriod(10)
    await this.staking.setRewardGeneratingAmountBaseIndex(8000)
    await this.staking.setWithdrawalAmountReducePerc(60)
    await this.staking.setWithdrawnBBroRewardReducePerc(60)
    await this.staking.setBBroRewardsBaseIndex(4000)
    await this.staking.setBBroRewardsXtraMultiplier(11)

    expect(await this.staking.distributor()).to.equal(this.mark.address)
    expect(await this.staking.minBroStakeAmount()).to.equal(ethers.utils.parseEther("2"))
    expect(await this.staking.minUnstakingPeriod()).to.equal(15)
    expect(await this.staking.maxUnstakingPeriod()).to.equal(364)
    expect(await this.staking.maxUnstakingPeriodsPerStaker()).to.equal(10)
    expect(await this.staking.maxWithdrawalsPerUnstakingPeriod()).to.equal(10)
    expect(await this.staking.rewardGeneratingAmountBaseIndex()).to.equal(BigNumber.from("800000000000000000"))
    expect(await this.staking.withdrawalAmountReducePerc()).to.equal(60)
    expect(await this.staking.withdrawnBBroRewardReducePerc()).to.equal(60)
    expect(await this.staking.bBroRewardsBaseIndex()).to.equal(BigNumber.from("400000000000000000"))
    expect(await this.staking.bBroRewardsXtraMultiplier()).to.equal(11)

    await expect(this.staking.setRewardGeneratingAmountBaseIndex(10_001)).to.be.revertedWith("Invalid decimals")
    await expect(this.staking.setWithdrawalAmountReducePerc(101)).to.be.revertedWith("Invalid decimals")
    await expect(this.staking.setWithdrawnBBroRewardReducePerc(101)).to.be.revertedWith("Invalid decimals")
    await expect(this.staking.setBBroRewardsBaseIndex(10_001)).to.be.revertedWith("Invalid decimals")

    await this.staking.removeProtocolMember(this.communityBonding.address)
    await expect(this.staking.protocolMembers(0)).to.be.reverted
    await expect(this.staking.removeProtocolMember(this.communityBonding.address)).to.be.revertedWith(
      "Protocol member not found"
    )
    await this.staking.addProtocolMember(this.communityBonding.address)
    await expect(this.staking.addProtocolMember(this.communityBonding.address)).to.be.revertedWith(
      "Address already added to the protocol members list"
    )
    expect(await this.staking.protocolMembers(0)).to.equal(this.communityBonding.address)

    await expect(this.staking.connect(this.paul).setDistributor(this.mark.address)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).addProtocolMember(this.paul.address)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).removeProtocolMember(this.paul.address)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setMinBroStakeAmount(ethers.utils.parseEther("2"))).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setMinUnstakingPeriod(15)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setMaxUnstakingPeriod(364)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setMaxUnstakingPeriodsPerStaker(10)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setMaxWithdrawalsPerUnstakingPeriod(10)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setRewardGeneratingAmountBaseIndex(8000)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setWithdrawalAmountReducePerc(60)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setWithdrawnBBroRewardReducePerc(60)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setBBroRewardsBaseIndex(4000)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    await expect(this.staking.connect(this.paul).setBBroRewardsXtraMultiplier(11)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
  })

  it("should not allow to use it's functionality when paused", async function () {
    await this.staking.pause()

    expect(await this.staking.paused()).to.equal(true)
    await expect(this.staking.stake(ethers.utils.parseEther("1"), 14)).to.be.revertedWith("Pausable: paused")
    await expect(
      this.staking
        .connect(this.communityBonding)
        .protocolMemberStake(this.mark.address, ethers.utils.parseEther("1"), 14)
    ).to.be.revertedWith("Pausable: paused")
    await expect(this.staking.compound(14)).to.be.revertedWith("Pausable: paused")
    await expect(this.staking.unstake(ethers.utils.parseEther("1"), 14)).to.be.revertedWith("Pausable: paused")
    await expect(this.staking.withdraw()).to.be.revertedWith("Pausable: paused")
    await expect(this.staking.cancelUnstaking(ethers.utils.parseEther("1"), 14)).to.be.revertedWith("Pausable: paused")
    await expect(this.staking.claimRewards(true, true)).to.be.revertedWith("Pausable: paused")

    await this.staking.unpause()
    expect(await this.staking.paused()).to.equal(false)
  })

  it("should transfer tokens back when zero staked", async function () {
    await this.broToken.connect(this.distributor).transfer(this.staking.address, ethers.utils.parseEther("1"))
    expect(await this.broToken.balanceOf(this.distributor.address)).to.equal(ethers.utils.parseEther("999"))
    expect(await this.broToken.balanceOf(this.staking.address)).to.equal(ethers.utils.parseEther("1"))

    await this.staking.connect(this.distributor).handleDistribution(ethers.utils.parseEther("1"))

    expect(await this.broToken.balanceOf(this.distributor.address)).to.equal(ethers.utils.parseEther("1000"))
    expect(await this.broToken.balanceOf(this.staking.address)).to.equal(ethers.utils.parseEther("0"))
  })

  it("should properly calculate rewards generating amount and per epoch staking rewards", async function () {
    await this.staking.setMaxUnstakingPeriodsPerStaker(14)
    await this.broToken.connect(this.mark).approve(this.staking.address, ethers.utils.parseEther("15"))

    var currentTime = await currentBlockchainTime(ethers.provider)

    for (const period of [14, 20, 25, 30, 40, 50, 75, 100, 150, 200, 250, 300, 350, 365]) {
      await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), period)
    }

    // exceed max unstaking period period
    await expect(this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 15)).to.be.revertedWith(
      "UnstakingPeriodsLimitWasReached()"
    )
    await expect(this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 13)).to.be.revertedWith(
      "Invalid unstaking period"
    )
    await expect(this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 400)).to.be.revertedWith(
      "Invalid unstaking period"
    )

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.broRewardIndex).to.equal(0)
    expect(staker.pendingBroReward).to.equal(0)
    expect(staker.pendingBBroReward).to.equal(0)

    // verify bro rewards generating amount calculation
    const unstakingPeriods = staker.unstakingPeriods
    expect(unstakingPeriods.length).to.equal(14)
    expect(unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7499")
    expect(unstakingPeriods[1].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7542")
    expect(unstakingPeriods[2].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7578")
    expect(unstakingPeriods[3].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7613")
    expect(unstakingPeriods[4].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7684")
    expect(unstakingPeriods[5].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7756")
    expect(unstakingPeriods[6].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7934")
    expect(unstakingPeriods[7].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("8112")
    expect(unstakingPeriods[8].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("8468")
    expect(unstakingPeriods[9].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("8824")
    expect(unstakingPeriods[10].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("9180")
    expect(unstakingPeriods[11].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("9536")
    expect(unstakingPeriods[12].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("9893")
    expect(unstakingPeriods[13].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("1000")

    expect((await this.staking.totalBroStaked()).toString().substring(0, 8)).to.equal("11762575")
    expect(await this.staking.globalBroRewardIndex()).to.equal(0)

    // distibute and skip 1 epoch
    await this.staking.connect(this.distributor).handleDistribution(ethers.utils.parseEther("100"))
    currentTime += 86401
    await setBlockchainTime(ethers.provider, currentTime)

    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(14)
    expect(staker.broRewardIndex).to.equal(await this.staking.globalBroRewardIndex())
    expect(staker.pendingBroReward.toString()).to.equal("99999999999999999988") // bit smaller then 100 BRO due to decimal calculations
    expect(staker.pendingBBroReward.toString().substring(0, 8)).to.equal("25001945")

    // must allow to adjust unstaking period
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)
    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(14)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 8)).to.equal("14999452")

    // must allow to exceed unstaking periods limit while staking from community bonding
    await this.broToken.connect(this.communityBonding).approve(this.staking.address, ethers.utils.parseEther("1"))
    await this.staking
      .connect(this.communityBonding)
      .protocolMemberStake(this.mark.address, ethers.utils.parseEther("1"), 15)

    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(15)
    expect(staker.unstakingPeriods[14].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7506")
  })

  it("should properly handle total staked bro and rewards generating amounts while unstaking", async function () {
    await this.broToken.connect(this.mark).approve(this.staking.address, ethers.utils.parseEther("2"))
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("2"), 14)

    expect((await this.staking.totalBroStaked()).toString().substring(0, 8)).to.equal("14999452")

    await expect(this.staking.connect(this.mark).unstake(ethers.utils.parseEther("1"), 13)).to.be.revertedWith(
      "UnstakingPeriodNotFound(13)"
    )

    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("1"), 14)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(1)
    expect(staker.withdrawals.length).to.equal(1)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7499")
    expect(staker.unstakingPeriods[0].lockedAmount.toString().substring(0, 4)).to.equal("2500")
    expect(staker.withdrawals[0].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("6749")
    expect(staker.withdrawals[0].lockedAmount.toString().substring(0, 4)).to.equal("3250")
    expect(staker.withdrawals[0].unstakingPeriod).to.equal(14)
    expect((await this.staking.totalBroStaked()).toString().substring(0, 8)).to.equal("14249479") // 7499 + 6749

    await expect(this.staking.connect(this.mark).cancelUnstaking(ethers.utils.parseEther("1"), 15)).to.be.revertedWith(
      "WithdrawalNotFound(1000000000000000000, 15)"
    )
    await expect(
      this.staking.connect(this.mark).cancelUnstaking(ethers.utils.parseEther("1.1"), 14)
    ).to.be.revertedWith("WithdrawalNotFound(1100000000000000000, 14)")

    // cancel withdrawal
    await this.staking.connect(this.mark).cancelUnstaking(ethers.utils.parseEther("1"), 14)

    await expect(this.staking.connect(this.mark).cancelUnstaking(ethers.utils.parseEther("1"), 14)).to.be.revertedWith(
      "WithdrawalNotFound(1000000000000000000, 14)"
    )

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(1)
    expect(staker.withdrawals.length).to.equal(0)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 8)).to.equal("14999452")
    expect(staker.unstakingPeriods[0].lockedAmount.toString().substring(0, 8)).to.equal("50005479")
    expect((await this.staking.totalBroStaked()).toString().substring(0, 8)).to.equal("14999452")
  })

  it("should properly compound accrued rewards and claim", async function () {
    await this.broToken.connect(this.mark).approve(this.staking.address, ethers.utils.parseEther("1"))
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)

    var currentTime = await currentBlockchainTime(ethers.provider)
    await this.staking.connect(this.distributor).handleDistribution(ethers.utils.parseEther("1"))
    currentTime += 86401
    await setBlockchainTime(ethers.provider, currentTime)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBroReward.toString()).to.equal("999999999999999999")
    expect(staker.pendingBBroReward.toString()).to.equal("827287671232876")
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 8)).to.equal("74997260")
    expect((await this.staking.totalBroStaked()).toString().substring(0, 8)).to.equal("74997260")

    await this.staking.connect(this.mark).compound(14)
    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBroReward.toString()).to.equal("0")
    expect(staker.pendingBBroReward.toString()).to.equal("827287671232876")
    expect((await this.staking.totalBroStaked()).toString().substring(0, 8)).to.equal("14999452")
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 8)).to.equal("14999452")

    await expect(this.staking.connect(this.mark).compound(14)).to.be.revertedWith("NothingToCompound()")

    await expect(this.staking.connect(this.mark).claimRewards(false, false)).to.be.revertedWith(
      "Must claim at least one token reward"
    )
    await expect(this.staking.connect(this.mark).claimRewards(true, false)).to.be.revertedWith("NothingToClaim()") // no bro rewards for now

    await this.staking.connect(this.mark).claimRewards(false, true) // must claim bbro
    expect((await this.bbroToken.balanceOf(this.mark.address)).toString()).to.equal("827287671232876")
    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBroReward.toString()).to.equal("0")
    expect(staker.pendingBBroReward.toString()).to.equal("0")

    await expect(this.staking.connect(this.mark).claimRewards(false, true)).to.be.revertedWith("NothingToClaim()") // no bbro rewards for now

    // distribute
    await this.broToken.connect(this.distributor).transfer(this.staking.address, ethers.utils.parseEther("5")) // just increase staking balance
    await this.staking.connect(this.distributor).handleDistribution(ethers.utils.parseEther("1"))
    currentTime += 86401
    await setBlockchainTime(ethers.provider, currentTime)

    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBroReward.toString()).to.equal("999999999999999999")
    expect(staker.pendingBBroReward.toString()).to.equal("1654575342465753")

    await this.staking.connect(this.mark).claimRewards(true, true)
    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBroReward.toString()).to.equal("0")
    expect(staker.pendingBBroReward.toString()).to.equal("0")
  })

  it("should allow to have only max amount of withdrawals per unstaking period", async function () {
    await this.broToken.connect(this.distributor).transfer(this.staking.address, ethers.utils.parseEther("5")) // just increase staking balance
    await this.broToken.connect(this.mark).approve(this.staking.address, ethers.utils.parseEther("2"))
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)

    var currentTime = await currentBlockchainTime(ethers.provider)

    // unstake 5 times (6 max)
    for (let i = 0; i < 5; i++) {
      await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 14)
    }

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.withdrawals.length).equal(5)
    for (let i = 0; i < staker.withdrawals.length; i++) {
      expect(staker.withdrawals[i].unstakingPeriod).to.equal(14)
    }

    await expect(this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 14)).to.be.revertedWith(
      "WithdrawalsLimitWasReached()"
    )

    // get some rewards and shift time
    currentTime += 86400 * 2
    await setBlockchainTime(ethers.provider, currentTime)

    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.5"), 14)

    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.withdrawals.length).to.equal(6)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString()).to.equal("0")
    expect(staker.unstakingPeriods[0].lockedAmount.toString()).to.equal("0")
    expect(staker.pendingBBroReward.toString()).to.equal("1240931506849311")

    await expect(this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 14)).to.be.revertedWith(
      "Unstake amount must be less then total staked amount per unstake"
    )

    // stake more and try to unstake
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)

    await expect(this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 14)).to.be.revertedWith(
      "Withdrawals limit reached. Wait until one of them will be released"
    )
    await expect(this.staking.connect(this.mark).unstake(ethers.utils.parseEther("1"), 14)).to.be.revertedWith(
      "Withdrawals limit reached. Wait until one of them will be released"
    )

    await expect(this.staking.connect(this.mark).withdraw()).to.be.revertedWith("NothingToWithdraw()")

    currentTime += 86400 * 12
    await setBlockchainTime(ethers.provider, currentTime)

    await expect(this.staking.connect(this.mark).withdraw())
      .to.emit(this.staking, "Withdrawn")
      .withArgs(this.mark.address, "500000000000000000")

    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("1"), 14)

    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(1)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString()).to.equal("0")
    expect(staker.unstakingPeriods[0].lockedAmount.toString()).to.equal("0")
    expect(staker.withdrawals.length).to.equal(2)
    expect(staker.pendingBroReward.toString()).to.equal("0")
    expect(staker.pendingBBroReward.toString()).to.equal("16132109589041061")

    // claim everything to remove unstaking period
    await this.staking.connect(this.mark).claimRewards(false, true)

    currentTime += 86400 * 15
    await setBlockchainTime(ethers.provider, currentTime)

    await this.staking.connect(this.mark).withdraw()

    staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(0)
  })

  it("should properly split rewards between stakers", async function () {
    await this.broToken.connect(this.mark).approve(this.staking.address, ethers.utils.parseEther("10"))
    await this.broToken.connect(this.bobo).approve(this.staking.address, ethers.utils.parseEther("10"))
    await this.broToken.connect(this.paul).approve(this.staking.address, ethers.utils.parseEther("10"))

    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 365)
    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 14)
    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.3"), 14)
    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 365)
    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 365)
    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("0.1"), 365)

    await this.staking.connect(this.bobo).stake(ethers.utils.parseEther("5"), 350)
    await this.staking.connect(this.bobo).unstake(ethers.utils.parseEther("1"), 350)

    await this.staking.connect(this.paul).stake(ethers.utils.parseEther("1"), 30)
    await this.staking.connect(this.paul).stake(ethers.utils.parseEther("1"), 100)
    await this.staking.connect(this.paul).stake(ethers.utils.parseEther("1"), 300)
    await this.staking.connect(this.paul).unstake(ethers.utils.parseEther("0.5"), 30)

    await this.staking.connect(this.distributor).handleDistribution(ethers.utils.parseEther("1"))

    const stakerMark = await this.staking.getStakerInfo(this.mark.address)
    const stakerBobo = await this.staking.getStakerInfo(this.bobo.address)
    const stakerPaul = await this.staking.getStakerInfo(this.paul.address)

    expect(stakerMark.pendingBroReward.toString().substring(0, 10)).to.equal("1872370604")
    expect(stakerBobo.pendingBroReward.toString().substring(0, 10)).to.equal("5370844424")
    expect(stakerPaul.pendingBroReward.toString().substring(0, 10)).to.equal("2756784971")

    var totalStaked = BigNumber.from("0")
    for (const staker of [stakerMark, stakerBobo, stakerPaul]) {
      for (let i = 0; i < staker.unstakingPeriods.length; i++) {
        totalStaked = totalStaked.add(staker.unstakingPeriods[i].rewardsGeneratingAmount)
      }

      for (let j = 0; j < staker.withdrawals.length; j++) {
        totalStaked = totalStaked.add(staker.withdrawals[j].rewardsGeneratingAmount)
      }
    }

    expect((await this.staking.totalBroStaked()).toString()).to.equal(totalStaked)
  })

  it("should stop generating bbro rewards for expired withdrawals and issue bro rewards", async function () {
    await this.broToken.connect(this.mark).approve(this.staking.address, ethers.utils.parseEther("1"))
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)

    var currentTime = await currentBlockchainTime(ethers.provider)

    // skip one epoch
    currentTime += 86401
    await setBlockchainTime(ethers.provider, currentTime)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBBroReward.toString()).to.equal("827287671232876")

    await this.staking.connect(this.mark).claimRewards(false, true)
    await this.staking.connect(this.mark).unstake(ethers.utils.parseEther("1"), 14)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBBroReward.toString()).to.equal("0")

    // skip one epoch
    currentTime += 86401
    await setBlockchainTime(ethers.provider, currentTime)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBBroReward.toString()).to.equal("413643835616438") // reward halfed

    // skip 12 epochs
    // current epoch 13
    currentTime += 86401 * 12
    await setBlockchainTime(ethers.provider, currentTime)
    await this.staking.connect(this.mark).claimRewards(false, true) // clear pending bbro reward

    // staker must receive only one bbro reward
    currentTime += 86401 * 12
    await setBlockchainTime(ethers.provider, currentTime)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBBroReward.toString()).to.equal("413643835616438")
    await this.staking.connect(this.mark).claimRewards(false, true) // clear pending bbro reward

    currentTime += 86401 * 12
    await setBlockchainTime(ethers.provider, currentTime)
    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBBroReward.toString()).to.equal("0") // no more bbro rewards

    // distribute to test bro rewards issueing
    await this.staking.connect(this.distributor).handleDistribution(ethers.utils.parseEther("1"))

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.pendingBroReward.toString()).to.equal("999999999999999999")
  })

  it("should properly increase unstaking period", async function () {
    await this.broToken.connect(this.mark).approve(this.staking.address, ethers.utils.parseEther("2"))
    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("7499")
    expect((await this.staking.totalBroStaked()).toString().substring(0, 4)).to.equal("7499")

    await this.staking.connect(this.mark).increaseUnstakingPeriod(14, 365)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("1000")
    expect((await this.staking.totalBroStaked()).toString().substring(0, 4)).to.equal("1000")

    await expect(this.staking.connect(this.mark).increaseUnstakingPeriod(14, 13)).to.be.revertedWith(
      "Unstaking period can only be increased"
    )
    await expect(this.staking.connect(this.mark).increaseUnstakingPeriod(15, 365)).to.be.revertedWith(
      "UnstakingPeriodNotFound(15)"
    )
    await expect(this.staking.connect(this.mark).increaseUnstakingPeriod(14, 366)).to.be.revertedWith(
      "Invalid unstaking period"
    )

    await this.staking.connect(this.mark).stake(ethers.utils.parseEther("1"), 14)

    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(2)

    await this.staking.connect(this.mark).increaseUnstakingPeriod(14, 365)
    var staker = await this.staking.getStakerInfo(this.mark.address)
    expect(staker.unstakingPeriods.length).to.equal(1)
    expect(staker.unstakingPeriods[0].rewardsGeneratingAmount.toString().substring(0, 4)).to.equal("2000")
    expect((await this.staking.totalBroStaked()).toString().substring(0, 4)).to.equal("2000")
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
