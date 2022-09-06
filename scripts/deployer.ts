import * as fs from "fs"
import { ethers, upgrades } from "hardhat"
import path from "path"

export async function deploy(configName: string, artifactName: string) {
  const config = readConfig(configName)

  // BRO TOKEN
  const BroToken = await ethers.getContractFactory("BroToken")
  const broToken = await BroToken.deploy("Bro Token", "BRO", config.ownerWallet)
  await broToken.deployed()

  await broToken.transferOwnership(config.ownerWallet)

  // BBRO TOKEN
  const BBroToken = await ethers.getContractFactory("BBroToken")
  const bbroToken = await upgrades.deployProxy(BBroToken, ["bBRO Token", "bBRO"])
  await bbroToken.deployed()

  await bbroToken.transferOwnership(config.ownerWallet)

  // EPOCH MANAGER
  const EpochManager = await ethers.getContractFactory("EpochManager")
  const epochManager = await EpochManager.deploy()
  await epochManager.deployed()

  await epochManager.transferOwnership(config.ownerWallet)

  // VESTING
  const Vesting = await ethers.getContractFactory("Vesting")
  const vesting = await Vesting.deploy(broToken.address)
  await vesting.deployed()

  await vesting.transferOwnership(config.ownerWallet)

  // AIRDROP
  const Airdrop = await ethers.getContractFactory("Airdrop")
  const airdrop = await Airdrop.deploy(broToken.address)
  await airdrop.deployed()

  await airdrop.transferOwnership(config.ownerWallet)

  // TOKEN DISTRIBUTOR
  const TokenDistributor = await ethers.getContractFactory("TokenDistributor")
  const tokenDistributor = await TokenDistributor.deploy(
    broToken.address,
    epochManager.address,
    config.tokenDistributor.distributionStart
  )
  await tokenDistributor.deployed()

  await tokenDistributor.transferOwnership(config.ownerWallet)

  // TREASURY
  const Treasury = await ethers.getContractFactory("Treasury")
  const treasury = await Treasury.deploy([])
  await treasury.deployed()

  await treasury.transferOwnership(config.ownerWallet)

  // NORMAL BONDING
  const BondingV1 = await ethers.getContractFactory("BondingV1")
  const normalBonding = await upgrades.deployProxy(BondingV1, [
    epochManager.address,
    broToken.address,
    treasury.address,
    tokenDistributor.address,
    config.normalBonding.minBroPayout,
  ])
  await normalBonding.deployed()

  await normalBonding.setNormalMode(config.normalBonding.vestingPeriod)
  await normalBonding.transferOwnership(config.ownerWallet)

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

  // COMMUNITY BONDING
  const communityBonding = await upgrades.deployProxy(BondingV1, [
    epochManager.address,
    broToken.address,
    treasury.address,
    tokenDistributor.address,
    config.normalBonding.minBroPayout,
  ])
  await communityBonding.deployed()

  await communityBonding.setCommunityMode(staking.address, config.communityBonding.unstakingPeriod)
  await communityBonding.transferOwnership(config.ownerWallet)

  // PROTOCOL MIGRATOR
  const ProtocolMigrator = await ethers.getContractFactory("ProtocolMigrator")
  const protocolMigrator = await ProtocolMigrator.deploy(
    broToken.address,
    bbroToken.address,
    staking.address,
    config.protocolMigrator.unstakingPeriod
  )
  await protocolMigrator.deployed()

  await protocolMigrator.transferOwnership(config.ownerWallet)

  // whitelist community bonding and protocol migrator
  await staking.addProtocolMember(communityBonding.address)
  await staking.addProtocolMember(protocolMigrator.address)
  await staking.transferOwnership(config.ownerWallet)

  writeArtifact(artifactName, {
    broToken: broToken.address,
    bBroToken: bbroToken.address,
    epochManager: epochManager.address,
    vesting: vesting.address,
    airdrop: airdrop.address,
    tokenDistributor: tokenDistributor.address,
    treasury: treasury.address,
    normalBonding: normalBonding.address,
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
