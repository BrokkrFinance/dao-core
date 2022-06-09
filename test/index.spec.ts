import { expect } from "chai"
import { ethers, upgrades } from "hardhat"

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
    const Greeter = await ethers.getContractFactory("Greeter")
    const greeter = await Greeter.deploy("Hello, world!")
    await greeter.deployed()

    expect(await greeter.greet()).to.equal("Hello, world!")

    const setGreetingTx = await greeter.setGreeting("Hola, mundo!")

    // wait until the transaction is mined
    await setGreetingTx.wait()

    expect(await greeter.greet()).to.equal("Hola, mundo!")
  })

  it("Testing upgradeability", async function () {
    const UpgradeableGreeter = await ethers.getContractFactory("UpgradeableGreeter")
    const upgradeableGreeter = await upgrades.deployProxy(UpgradeableGreeter, ["helloooo"])
    await upgradeableGreeter.deployed()

    expect(await upgradeableGreeter.greet()).to.equal("helloooo")

    const UpgradeableGreeterV2 = await ethers.getContractFactory("UpgradeableGreeterV2")
    const upgradeableGreeterV2 = await upgrades.upgradeProxy(upgradeableGreeter.address, UpgradeableGreeterV2, {
      call: { fn: "initialize", args: ["hahoooo"] },
    })
    await upgradeableGreeterV2.deployed()

    expect(await upgradeableGreeter.greet()).to.equal("hahoooo")
  })
})
