// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import { IUniV3SwapCallback } from "test/interfaces/IUniV3SwapCallback.sol";

contract UniV3PoolMock {
    event Swap(
        address sender,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceX96,
        bytes data
    );

    bool internal _shouldDoCallback = false;
    bool internal _shouldThrow = false;
    int256 internal _amount0Delta = 0x01;
    int256 internal _amount1Delta = 0x02;

    function setDoCallback(
        bool shouldDoCallback
    ) public {
        _shouldDoCallback = shouldDoCallback;
    }

    function setShouldThrow(
        bool shouldThrow
    ) public {
        _shouldThrow = shouldThrow;
    }

    function setDeltas(
        int256 amount0Delta,
        int256 amount1Delta
    ) public {
        _amount0Delta = amount0Delta;
        _amount1Delta = amount1Delta;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public {
        require(!_shouldThrow);

        emit Swap(msg.sender, recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data);

        if (_shouldDoCallback) {
            IUniV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                _amount0Delta,
                _amount1Delta,
                data
            );
        }
    }
}
