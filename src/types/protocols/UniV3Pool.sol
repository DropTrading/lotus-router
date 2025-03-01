// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import { BytesCalldata } from "src/types/BytesCalldata.sol";

type UniV3Pool is address;

using { swap } for UniV3Pool global;

uint256 constant swapSelector = 0x128acb0800000000000000000000000000000000000000000000000000000000;

function swap(
    UniV3Pool pool,
    address recipient,
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

        mstore(add(fmp, 0x04), recipient)

        mstore(add(fmp, 0x24), zeroForOne)

        mstore(add(fmp, 0x44), amountSpecified)

        mstore(add(fmp, 0x64), sqrtPriceLimitX96)

        mstore(add(fmp, 0x84), 0xa0)

        mstore(add(fmp, 0xa4), dataLen)

        calldatacopy(add(fmp, 0xc4), data, dataLen)

        success := call(gas(), pool, 0x00, fmp, add(dataLen, 0xe4), 0x00, 0x00)
    }
}
