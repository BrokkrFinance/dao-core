import type * as ethersTypes from "ethers"

export async function currentBlockchainTime(provider: ethersTypes.providers.JsonRpcProvider) {
  return await (
    await provider.getBlock(await provider.getBlockNumber())
  ).timestamp
}

export async function setBlockchainTime(provider: ethersTypes.providers.JsonRpcProvider, time: number) {
  await provider.send("evm_mine", [time])
}
