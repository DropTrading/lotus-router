// SPDX-License-Identifier: Unlicense
import { BytesCalldata } from "src/types/BytesCalldata.sol";

interface IUniV4PoolManager {
    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external returns (BalanceDelta swapDelta);
}


uint256 constant unlockSelector = 0x48c8949100000000000000000000000000000000000000000000000000000000;
uint256 constant swapSelector = 0xf3cd914c00000000000000000000000000000000000000000000000000000000;
uint256 constant syncSelector = 0xa584119400000000000000000000000000000000000000000000000000000000;
uint256 constant settleSelector = 0x11da60b400000000000000000000000000000000000000000000000000000000;
uint256 constant takeSelector = 0x0b0d9c0900000000000000000000000000000000000000000000000000000000;
uint256 constant transferSelector =
    0xa9059cbb00000000000000000000000000000000000000000000000000000000;
type UniV4PoolManager is address;
using { swapAllInOne, swap, settle,take, sync, unlock } for UniV4PoolManager global;

type IHooks is address;


// 给池子和数量，swap sync transfer settle take 全部自动执行, transfer 从
// 由 unlocker 调用
function swapAllInOne(
            UniV4PoolManager poolManager,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing,
            address hook,
            bool zeroForOne,
            int256 amountSpecified,
            uint160 sqrtPriceLimitX96,
            address to, // token to
            BytesCalldata data
) returns (bool success) {
    int128 delta0;
    int128 delta1;

    // swap
    assembly ("memory-safe") {
        let fmp := mload(0x40)
        let dataLen := shr(0xe0, calldataload(data))
        data := add(data, 0x04)

        mstore(add(fmp, 0x00), swapSelector)
        mstore(add(fmp, 0x04), token0)
        mstore(add(fmp, 0x24), token1)
        mstore(add(fmp, 0x44), fee)
        mstore(add(fmp, 0x64), tickSpacing)
        mstore(add(fmp, 0x84), hook)
        mstore(add(fmp, 0xa4), zeroForOne)
        mstore(add(fmp, 0xc4), amountSpecified)
        mstore(add(fmp, 0xe4), sqrtPriceLimitX96)

        mstore(add(fmp, 0x104), add(fmp, 0))

        mstore(add(fmp, 0x124), dataLen)

        calldatacopy(add(fmp, 0x144), data, dataLen)

        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, add(dataLen, 0x164), 0x00, 0x20)

        returndatacopy(0x00,0x00,0x20)

        delta0 := sar(128, mload(0x00))
        delta1 := signextend(15, mload(0x00))
    }

    address tokenIn = zeroForOne? token0: token1;
    address tokenOut = zeroForOne? token1: token0;

    // sync
    assembly ("memory-safe") {
        let fmp := mload(0x40)

        mstore(add(fmp, 0x00), syncSelector)
        mstore(add(fmp, 0x04), tokenIn)
        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, 0x24, 0x00, 0x00)
    }

    uint128 amountIn =  uint128(delta0<0 ? -delta0: delta1) ;
    uint128 amountOut =  uint128(delta0>0 ? delta0: -delta1) ;

    // transfer
    assembly ("memory-safe") {
        let fmp := mload(0x40)

        mstore(add(fmp, 0x00), transferSelector)
        mstore(add(fmp,0x04), 0x000000000004444c5dc75cB358380D2e3dE08A90)
        mstore(add(fmp,0x24), amountOut)

        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, 0x44, 0x00, 0x00)
    }

    // settle
    assembly ("memory-safe") {
        let fmp := mload(0x40)
        mstore(add(fmp, 0x00), settleSelector)
        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, 0x20, 0x00, 0x00)
    }

    // take
    assembly ("memory-safe") {
        let fmp := mload(0x40)
        mstore(add(fmp, 0x00), takeSelector)
        mstore(add(fmp, 0x04), to)
        mstore(add(fmp, 0x04), amountOut)
        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, 0x20, 0x00, 0x00)
    }



}

function unlock(
    UniV4PoolManager poolManager,
    BytesCalldata data
) returns (bool success) {
    assembly ("memory-safe") {
        let fmp := mload(0x40)
        let dataLen := shr(0xe0, calldataload(data))
        data := add(data, 0x04)

        mstore(add(fmp, 0x00), unlockSelector)

        //mstore(add(fmp, 0x04), add(fmp , 0x20) )
        mstore(add(fmp, 0x04),  0x20 )
        mstore(add(fmp, 0x24),  dataLen)

        calldatacopy(add(fmp, 0x44), data, dataLen)

        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, add(dataLen, 0x44), 0x00, 0x00)
    }
}


function swap(
            UniV4PoolManager poolManager,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing,
            address hook,
            bool zeroForOne,
            int256 amountSpecified,
            uint160 sqrtPriceLimitX96,
            BytesCalldata data
) returns (bool success) {
    assembly ("memory-safe") {
        let fmp := mload(0x40)
        let dataLen := shr(0xe0, calldataload(data))
        data := add(data, 0x04)

        mstore(add(fmp, 0x00), swapSelector)

        mstore(add(fmp, 0x04), 0x20 )
        mstore(add(fmp, 0x24), add(dataLen, 0x144 ))

        mstore(add(fmp, 0x44), swapSelector)
        mstore(add(fmp, 0x48), token0)
        mstore(add(fmp, 0x68), token1)
        mstore(add(fmp, 0x88), fee)
        mstore(add(fmp, 0xa8), tickSpacing)
        mstore(add(fmp, 0xc8), hook)
        mstore(add(fmp, 0xe8), zeroForOne)
        mstore(add(fmp, 0x108), amountSpecified)
        mstore(add(fmp, 0x128), sqrtPriceLimitX96)

        mstore(add(fmp, 0x148), 0x120)

        mstore(add(fmp, 0x168), dataLen)

        calldatacopy(add(fmp, 0x168), data, dataLen)

        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, add(dataLen, 0x188), 0x00, 0x00)
    }
}

function settle(
    UniV4PoolManager poolManage
) returns (bool success) {
    assembly ("memory-safe") {
        let fmp := mload(0x40)
        mstore(add(fmp, 0x00), settleSelector)

        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, 0x20, 0x00, 0x00)
    }
}

function take(
            UniV4PoolManager poolManager,
            address currency,
            address to,
            uint256 amount
) returns (bool success) {
    // 得先 unlock 0x48c89491
    assembly ("memory-safe") {
        let fmp := mload(0x40)

        mstore(add(fmp, 0x00), takeSelector)

        mstore(add(fmp, 0x04), currency)
        mstore(add(fmp, 0x24), to)
        mstore(add(fmp, 0x44), amount)

        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, 0x64, 0x00, 0x00)
    }
}

function sync(
            UniV4PoolManager poolManager,
            address currency
) returns (bool success) {
    // 得先 unlock 0x48c89491
    assembly ("memory-safe") {
        let fmp := mload(0x40)

        mstore(add(fmp, 0x00), syncSelector)

        mstore(add(fmp, 0x04), currency)

        success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, 0x24, 0x00, 0x00)
    }
}



struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}
type Currency is address;
type PoolId is bytes32;
type BalanceDelta is int256;


struct PoolKey {
    /// @notice The lower currency of the pool, sorted numerically
    Currency currency0;
    /// @notice The higher currency of the pool, sorted numerically
    Currency currency1;
    /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
    uint24 fee;
    /// @notice Ticks that involve positions must be a multiple of tick spacing
    int24 tickSpacing;
    /// @notice The hooks of the pool
    IHooks hooks;
}