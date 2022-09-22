import { expect } from "chai"
import * as fs from "fs"
import { ethers, upgrades } from "hardhat"
import path from "path"

async function sleep(timeout: number) {
  await new Promise((resolve) => setTimeout(resolve, timeout))
}

async function retryUntilSuccess<T>(fut: Promise<T>) {
  while (true) {
    try {
      const resolved = await expectSuccess(fut)
      if (resolved !== undefined) {
        return resolved
      } else {
        console.log(`Error because resolved promise is undefined`)
      }
    } catch (e: unknown) {
      console.log(`Error when expecting Success: ${e}`)
    }
  }
}

async function expectSuccess<T>(fut: Promise<T>) {
  let resolvedPromise: Promise<T>
  try {
    const resolved = await fut
    resolvedPromise = new Promise<T>((resolve, reject) => {
      resolve(resolved)
    })
  } catch (e: any) {
    resolvedPromise = new Promise((resolve, reject) => {
      throw e
    })
    if ("error" in e) {
      console.log(e.error)
    } else console.log(e)
  }
  await expect(resolvedPromise).not.to.be.reverted
  return await resolvedPromise
}

export async function deploy(configName: string, artifactName: string) {
  const config = readConfig(configName)

  // BRO TOKEN
  const BroToken = await ethers.getContractFactory("BroToken")
  const broToken = await BroToken.deploy("Bro Token", "BRO", config.broBalanceHolder)
  await broToken.deployed()

  await broToken.transferOwnership(config.ownerWallet)

  console.log("BRO TOKEN DEPLOYED")
  await sleep(5000)

  // BBRO TOKEN
  const BBroToken = await ethers.getContractFactory("BBroToken")
  const bbroToken = await upgrades.deployProxy(BBroToken, ["bBRO Token", "bBRO"])
  await bbroToken.deployed()

  console.log("BBRO TOKEN DEPLOYED")
  await sleep(5000)

  // EPOCH MANAGER
  const EpochManager = await ethers.getContractFactory("EpochManager")
  const epochManager = await EpochManager.deploy()
  await epochManager.deployed()

  await epochManager.transferOwnership(config.ownerWallet)

  console.log("EPOCH MANAGER DEPLOYED")
  await sleep(5000)

  // VESTING
  const Vesting = await ethers.getContractFactory("Vesting")
  const vesting = await Vesting.deploy(broToken.address)
  await vesting.deployed()

  await vesting.transferOwnership(config.ownerWallet)

  console.log("VESTING DEPLOYED")
  await sleep(5000)

  // AIRDROP
  const Airdrop = await ethers.getContractFactory("Airdrop")
  const airdrop = await Airdrop.deploy(broToken.address)
  await airdrop.deployed()

  await airdrop.transferOwnership(config.ownerWallet)

  console.log("AIRDROP DEPLOYED")
  await sleep(5000)

  // TOKEN DISTRIBUTOR
  const TokenDistributor = await ethers.getContractFactory("TokenDistributor")
  const tokenDistributor = await TokenDistributor.deploy(
    broToken.address,
    epochManager.address,
    config.tokenDistributor.distributionStart
  )
  await tokenDistributor.deployed()

  console.log("TOKEN DISTRIBUTOR")
  await sleep(5000)

  // TREASURY
  const Treasury = await ethers.getContractFactory("Treasury")
  const treasury = await Treasury.deploy([])
  await treasury.deployed()

  await treasury.transferOwnership(config.ownerWallet)

  console.log("TREASURY")
  await sleep(5000)

  // NORMAL BONDING
  const BondingV1 = await ethers.getContractFactory("BondingV1")
  // const normalBonding = await upgrades.deployProxy(BondingV1, [
  //   epochManager.address,
  //   broToken.address,
  //   treasury.address,
  //   tokenDistributor.address,
  //   config.normalBonding.minBroPayout,
  // ])
  // await normalBonding.deployed()

  // await normalBonding.setNormalMode(config.normalBonding.vestingPeriod)
  // await normalBonding.transferOwnership(config.ownerWallet)

  // STAKING
  const Staking = await ethers.getContractFactory("StakingV1")
  const staking = await upgrades.deployProxy(Staking, [
    [
      tokenDistributor.address,
      epochManager.address,
      broToken.address,
      bbroToken.address,
      [],
      config.staking.minBroStakeAmount,
      config.staking.minUnstakingPeriod,
      config.staking.maxUnstakingPeriod,
      config.staking.maxUnstakingPeriodsPerStaker,
      config.staking.maxWithdrawalsPerUnstakingPeriod,
      config.staking.rewardGeneratingAmountBaseIndex,
      config.staking.withdrawalAmountReducePerc,
      config.staking.withdrawnBBroRewardReducePerc,
      config.staking.bBroRewardsBaseIndex,
      config.staking.bBroRewardsXtraMultiplier,
    ],
  ])
  await staking.deployed()

  console.log("STAKING")
  await sleep(5000)

  // COMMUNITY BONDING
  const communityBonding = await upgrades.deployProxy(BondingV1, [
    epochManager.address,
    broToken.address,
    treasury.address,
    tokenDistributor.address,
    config.normalBonding.minBroPayout,
  ])
  await communityBonding.deployed()

  console.log("COMMUNITY BONDING")
  await sleep(5000)

  await communityBonding.setCommunityMode(staking.address, config.communityBonding.unstakingPeriod)
  console.log("COMMUNITY MODE SET")
  await sleep(5000)

  await communityBonding.transferOwnership(config.ownerWallet)
  console.log("")
  await sleep(5000)

  // PROTOCOL MIGRATOR
  const ProtocolMigrator = await ethers.getContractFactory("ProtocolMigrator")
  const protocolMigrator = await ProtocolMigrator.deploy(
    broToken.address,
    bbroToken.address,
    staking.address,
    config.protocolMigrator.unstakingPeriod
  )
  await protocolMigrator.deployed()

  await protocolMigrator.transferOwnership(config.protocolMigrator.owner)

  console.log("PROTOCOL MIGRATOR DEPLOYED")
  await sleep(5000)

  // whitelist community bonding and protocol migrator
  await retryUntilSuccess(staking.addProtocolMember(communityBonding.address))
  console.log("1")
  await retryUntilSuccess(staking.addProtocolMember(protocolMigrator.address))
  console.log("2")
  await retryUntilSuccess(staking.transferOwnership(config.ownerWallet))
  console.log("3")

  // await retryUntilSuccess(bbroToken.whitelistAddress(staking.address))
  // console.log("4")
  // await retryUntilSuccess(bbroToken.whitelistAddress(protocolMigrator.address))
  // console.log("5")
  // await retryUntilSuccess(bbroToken.transferOwnership(config.ownerWallet))
  // console.log("6")

  // await retryUntilSuccess(tokenDistributor.addDistribution(staking.address, ethers.utils.parseEther("125000")))
  // console.log("7")
  // await retryUntilSuccess(tokenDistributor.transferOwnership(config.ownerWallet))
  // console.log("8")

  writeArtifact(artifactName, {
    broToken: broToken.address,
    bBroToken: bbroToken.address,
    epochManager: epochManager.address,
    vesting: vesting.address,
    airdrop: airdrop.address,
    tokenDistributor: tokenDistributor.address,
    treasury: treasury.address,
    normalBonding: "sex_on_the_beach", // normalBonding.address,
    staking: staking.address,
    communityBonding: communityBonding.address,
    protocolMigrator: protocolMigrator.address,
  })
}

function readConfig(configName: string): Config {
  const CONFIG_PATH = "./scripts/config"
  const data = fs.readFileSync(path.join(CONFIG_PATH, `${configName}.json`), "utf8")
  return JSON.parse(data)
}

function writeArtifact(artifactName: string, artifact: Artifact) {
  const ARTIFACT_PATH = "./scripts/artifacts"
  if (!fs.existsSync(ARTIFACT_PATH)) {
    fs.mkdirSync(ARTIFACT_PATH)
  }

  fs.writeFileSync(path.join(ARTIFACT_PATH, `${artifactName}.json`), JSON.stringify(artifact, null, 2))
}

interface Config {
  broBalanceHolder: string
  ownerWallet: string
  tokenDistributor: {
    distributionStart: number
  }
  normalBonding: {
    minBroPayout: number
    vestingPeriod: number
  }
  staking: {
    minBroStakeAmount: number
    minUnstakingPeriod: number
    maxUnstakingPeriod: number
    maxUnstakingPeriodsPerStaker: number
    maxWithdrawalsPerUnstakingPeriod: number
    rewardGeneratingAmountBaseIndex: number
    withdrawalAmountReducePerc: number
    withdrawnBBroRewardReducePerc: number
    bBroRewardsBaseIndex: number
    bBroRewardsXtraMultiplier: number
  }
  communityBonding: {
    unstakingPeriod: number
  }
  protocolMigrator: {
    owner: string
    unstakingPeriod: number
  }
}

interface Artifact {
  broToken: string
  bBroToken: string
  epochManager: string
  vesting: string
  airdrop: string
  tokenDistributor: string
  treasury: string
  normalBonding: string
  staking: string
  communityBonding: string
  protocolMigrator: string
}
