// SPDX-License-Identifier: Unlicense
import { BytesCalldata } from "src/types/BytesCalldata.sol";

interface IUniV4PoolManager {
    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external returns (BalanceDelta swapDelta);
}

uint256 constant swapSelector = 0xf3cd914c00000000000000000000000000000000000000000000000000000000;

contract UniV4PoolManager {
    // function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData) public 
    function swap(
                address token0,
                address token1,
                uint24 fee,
                int24 tickSpacing,
                address hook,
                bool zeroForOne,
                int256 amountSpecified,
                uint160 sqrtPriceLimitX96,
                BytesCalldata data
    ) public returns (bool success) {
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

            mstore(add(fmp, 0x104), 0x120)

            mstore(add(fmp, 0x124), dataLen)

            calldatacopy(add(fmp, 0x144), data, dataLen)

            success := call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, fmp, add(dataLen, 0x164), 0x00, 0x00)
        }
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

interface IHooks {
}

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