// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import {Action} from "src/types/Action.sol";
import {BytesCalldata} from "src/types/BytesCalldata.sol";

import {Error} from "src/types/Error.sol";
import {Ptr, findPtr} from "src/types/PayloadPointer.sol";
import {ERC20} from "src/types/protocols/ERC20.sol";
import {ERC6909} from "src/types/protocols/ERC6909.sol";
import {ERC721} from "src/types/protocols/ERC721.sol";
import {UniV1Exchange} from "src/types/protocols/UniV1Exchange.sol";
import {UniV2Pair} from "src/types/protocols/UniV2Pair.sol";
import {UniV3Pool} from "src/types/protocols/UniV3Pool.sol";
import {WETH} from "src/types/protocols/WETH.sol";
import {dynCall} from "src/types/protocols/Dyn.sol";
import {BBCDecoder} from "src/util/BBCDecoder.sol";
import {BBCEncoder} from "src/util/BBCEncoder.sol";
import {SwapParams, PoolKey, Currency, IHooks} from "src/types/protocols/UniV4Pool.sol";

struct PathInfo {
    address poolAddress;
    uint16 poolType;
    uint8 direction;
    uint24 fee;
    uint256 amountIn;
    uint256 amountOut;
    // for v4
    // bytes32 poolId;
    address currency0;
    address currency1;
    int24 tickSpacing;
    address hooks;
}

contract LotusRouterEncoder {
    constructor(bytes[] memory req) {
        // 解码路径数据
        // req 中的每个元素都是编码后的路径数据
        // 格式: ['address','address','uint8','uint24', 'address','address','int24','address']
        // 对应: [currency0, currency1, direction, poolAddress, tickSpacing, poolType, hooks, fee]

        uint256 pathCount = req.length;
        bytes[] memory datas = new bytes[](pathCount);
        PathInfo[] memory pathInfos = new PathInfo[](pathCount);

        for (uint256 i = 0; i < pathCount; i++) {
            bytes memory pathData = req[i];

            // 解码路径数据
            // 根据 JavaScript 代码的编码顺序：
            // ['address','address','uint8','uint24', 'address','address','int24','address']
            // [path.currency0, path.currency1, path.direction, path.poolAddress, path.tickSpacing, path.poolType, path.hooks, path.fee]
            (
                address currency0,
                address currency1,
                uint8 direction,
                address poolAddress,
                int24 tickSpacing,
                uint16 poolType,
                address hooks,
                uint24 fee,
                uint256 amountIn,
                uint256 amountOut
            ) = abi.decode(
                    pathData,
                    (
                        address,
                        address,
                        uint8,
                        address,
                        int24,
                        uint16,
                        address,
                        uint24,
                        uint256,
                        uint256
                    )
                );

            // 将 address 类型的 tickSpacing 转换为 int24

            pathInfos[i] = PathInfo({
                poolAddress: poolAddress,
                poolType: poolType,
                direction: direction,
                fee: fee,
                amountIn: amountIn,
                amountOut: amountOut,
                currency0: currency0,
                currency1: currency1,
                tickSpacing: tickSpacing,
                hooks: hooks
            });
        }

        {
            address router = 0xFcE863461C1E27cA10A19939b8426bB8F4d61de2;
            address to = router;

            bytes memory data = new bytes(0);
            bool useCallback = true;

            if (
                pathInfos[0].poolType == 1000 || pathInfos[0].poolType == 9001
            ) {
                useCallback = false;
            }

            // 正确初始化 encoded 数组大小
            uint256 encodedLength = useCallback ? pathCount - 1 : pathCount;
            bytes[] memory encoded = new bytes[](encodedLength);

            for (uint256 i = useCallback ? 1 : 0; i < pathCount; i++) {
                PathInfo memory p = pathInfos[i];
                uint256 encodedIndex = useCallback ? i - 1 : i;
                encoded[encodedIndex] = encodeSingleCycle(p, to, data, false, i, pathCount);
            }

            if (useCallback) {
                // 拼接所有 encoded 元素
                bytes memory concatenatedData = new bytes(0);
                for (uint256 i = 0; i < encoded.length; i++) {
                    concatenatedData = abi.encodePacked(
                        concatenatedData,
                        encoded[i]
                    );
                }

                // 使用拼接后的数据调用第一个路径
                bytes memory finalData = encodeSingleCycle(
                    pathInfos[0],
                    to,
                    pathInfos[0].poolType == 2000?  abi.encodePacked(
                        concatenatedData,
                        encodeTransferERC20(
                            false,
                            pathInfos[0].direction == 1
                                ? pathInfos[0].currency0
                                : pathInfos[0].currency1,
                            pathInfos[0].poolAddress,
                            pathInfos[0].amountIn
                        )
                    ) :   concatenatedData ,
                    true,
                    pathCount-1,
                    pathCount
                );

                // 返回最终结果
                assembly {
                    return(add(finalData, 32), mload(finalData))
                }
            } else {
                // 如果不使用 callback，直接拼接所有编码结果
                bytes memory result = new bytes(0);
                for (uint256 i = 0; i < encoded.length; i++) {
                    result = abi.encodePacked(result, encoded[i]);
                }

                assembly {
                    return(add(result, 32), mload(result))
                }
            }
        }
    }

    function encodeSingleCycle(
        PathInfo memory p,
        address to,
        bytes memory data,
        bool lastPath,
        uint256 i,
        uint256 pathCount
    ) public returns (bytes memory encoded) {
        if (p.poolType == 1000) {
            encoded = BBCEncoder.encodeSwapUniV1(
                false,
                p.poolAddress,
                p.amountIn,
                p.amountOut,
                to
            );
        } else if (p.poolType == 2000) {
            encoded =  lastPath ?  
             BBCEncoder.encodeSwapUniV2(
                    false,
                    p.poolAddress,
                    p.direction == 16 ? p.amountOut : 0,
                    p.direction == 1 ? p.amountOut : 0,
                    to,
                    // data可以为0,为0 不执行callback
                    data.length == 0 ? new bytes(0) : abi.encodePacked(data)
                )
            : abi.encodePacked(
                BBCEncoder.encodeTransferERC20(
                    false,
                    p.direction == 1 ? p.currency0 : p.currency1,
                    p.poolAddress,
                    p.amountIn
                ),
                BBCEncoder.encodeSwapUniV2(
                    false,
                    p.poolAddress,
                    p.direction == 16 ? p.amountOut : 0,
                    p.direction == 1 ? p.amountOut : 0,
                    to,
                    // data可以为0,为0 不执行callback
                    data.length == 0 ? new bytes(0) : abi.encodePacked(data)
                )
            );
        } else if (p.poolType == 3000) {
            // 可以优化成支付给msg.sender
            bytes memory repay = BBCEncoder.encodeTransferERC20(
                false,
                p.direction == 1 ? p.currency0 : p.currency1,
                p.poolAddress,
                p.amountIn
            );
            encoded = BBCEncoder.encodeSwapUniV3(
                false,
                p.poolAddress,
                to,
                p.direction == 1,
                -int256(p.amountOut), // 正:精确输入 负:精确输出
                0,
                abi.encodePacked(
                    data.length == 0 ? repay : abi.encodePacked(data, repay)
                )
            );
        } else if (p.poolType == 4000) {
            // 如果接下来多个pool都是v4可以聚合，统一settle

            SwapParams memory swapParam = SwapParams({
                zeroForOne: p.direction == 1,
                amountSpecified: int(p.amountOut), // 和 v3 相反，amountSpecified 为正数，表示精确输出。返回的 amountIn 为负数，表示输入代币数量。
                sqrtPriceLimitX96: 0
            });

            encoded = BBCEncoder.encodeUniV4SwapAllInOne(
                abi.encodePacked(
                    p.currency0,
                    p.currency1,
                    p.fee,
                    p.tickSpacing,
                    p.hooks,
                    p.direction == 1,
                    p.amountOut,
                    uint256(0),
                    to,
                    hex""
                )
            );
        } else if (p.poolType == 9001) {
            encoded = p.direction == 1
                ? BBCEncoder.encodeDepositWETH(false, p.amountIn)
                : BBCEncoder.encodeWithdrawWETH(false, p.amountIn);
        } else {
            // 对于未知的 poolType，返回空字节数组
            encoded = new bytes(0);
        }
    }

    function _constructor(
        Action[] memory actions,
        bytes[] memory datas
    ) public {
        uint32 dataOffset = 0;
        bytes memory result = new bytes(0);

        bool canFail;
        address pair;
        uint256 amountIn;
        uint256 amountOut;
        uint256 amount0Out;
        uint256 amount1Out;
        address to;
        bytes memory data;

        address pool;
        address recipient;
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;

        address currency0;
        address currency1;
        address hook;
        uint24 fee;
        int24 tickSpacing;

        // 如果第一个池是v2v3 那就用callback, 先跳过第一个action, 构造 data
        // for (uint i = firstActionIsV2V3V4? 1:0; i < actions.length; i++) {
        for (uint i = 0; i < actions.length; i++) {
            Action action = actions[i];
            bytes memory encoded;

            if (action == Action.SwapUniV1) {
                (canFail, pair, amountIn, amountOut, to) = abi.decode(
                    datas[dataOffset++],
                    (bool, address, uint256, uint256, address)
                );

                encoded = encodeSwapUniV1(
                    canFail,
                    pair,
                    amountIn,
                    amountOut,
                    to
                );
            } else if (action == Action.SwapUniV2) {
                (canFail, pair, amount0Out, amount1Out, to, data) = abi.decode(
                    datas[dataOffset++],
                    (bool, address, uint256, uint256, address, bytes)
                );

                encoded = encodeSwapUniV2(
                    canFail,
                    pair,
                    amount0Out,
                    amount1Out,
                    to,
                    data
                );
            } else if (action == Action.SwapUniV3) {
                (
                    canFail,
                    pool,
                    recipient,
                    zeroForOne,
                    amountSpecified,
                    sqrtPriceLimitX96,
                    data
                ) = abi.decode(
                    datas[dataOffset++],
                    (bool, address, address, bool, int256, uint160, bytes)
                );

                encoded = encodeSwapUniV3(
                    canFail,
                    pool,
                    recipient,
                    zeroForOne,
                    amountSpecified,
                    sqrtPriceLimitX96,
                    data
                );
            } else if (action == Action.UniV4SwapAllInOne) {
                // (currency0,currency1, fee,tickSpacing, hook,
                // zeroForOne, amountSpecified,sqrtPriceLimitX96, to, data) =
                //     abi.decode(datas[dataOffset++],(address, address, uint24,int24,address, bool,int256, uint160, address, bytes));
                // PoolKey memory pk = PoolKey({
                //     currency0: Currency.wrap(currency0),
                //     currency1: Currency.wrap(currency1),
                //     fee: fee,
                //     tickSpacing: tickSpacing,
                //     hooks: IHooks.wrap(hook)
                // });

                // SwapParams memory swapParams = SwapParams({
                //     zeroForOne: zeroForOne,
                //     amountSpecified: amountSpecified,
                //     sqrtPriceLimitX96: sqrtPriceLimitX96
                // });

                encoded = BBCEncoder.encodeUniV4SwapAllInOne(
                    // pk,
                    // swapParams,
                    // to,
                    // data
                    datas[dataOffset++]
                );
            } else if (action == Action.UniV4Unlock) {
                encoded = encodeUniV4Unlock(datas[dataOffset++]);
            } else if (action == Action.TransferERC20) {
                // can,token,receiver,amount
                (canFail, currency0, recipient, amountIn) = abi.decode(
                    datas[dataOffset++],
                    (bool, address, address, uint256)
                );
                encoded = encodeTransferERC20(
                    canFail,
                    currency0,
                    recipient,
                    amountIn
                );
            } else if (action == Action.DepositWETH) {
                (canFail, amountIn) = abi.decode(
                    datas[dataOffset++],
                    (bool, uint256)
                );
                encoded = BBCEncoder.encodeDepositWETH(canFail, amountIn);
            } else if (action == Action.WithdrawWETH) {
                (canFail, amountIn) = abi.decode(
                    datas[dataOffset++],
                    (bool, uint256)
                );
                encoded = BBCEncoder.encodeWithdrawWETH(canFail, amountIn);
            }

            assembly {
                let encodedLen := mload(encoded)
                let resultPtr := add(add(result, 32), mload(result))
                let encodedPtr := add(encoded, 32)
                pop(
                    staticcall(
                        gas(),
                        0x04,
                        encodedPtr,
                        encodedLen,
                        resultPtr,
                        encodedLen
                    )
                )
                mstore(result, add(mload(result), encodedLen))
            }
        }

        // 在callback中闭合环，归还path1的输入token
        // if(firstActionIsV2V3V4) {
        //     bytes memory finalArg = new bytes(0);
        //     dataOffset = 0;

        //     if(actions[0] == Action.SwapUniV2) {
        //         (canFail,pair, amount0Out, amount1Out, to, data) =
        //             abi.decode(datas[dataOffset],(bool, address, uint256, uint256, address, bytes));

        //         finalArg = encodeSwapUniV2(
        //             canFail,
        //             pair,
        //             amount0Out,
        //             amount1Out,
        //             to,
        //             result
        //         );
        //     }else if(actions[0] == Action.SwapUniV3) {
        //         (canFail,pool, recipient,zeroForOne,amountSpecified,sqrtPriceLimitX96, data) =
        //             abi.decode(datas[dataOffset],(bool, address, address, bool,int256, uint160, bytes));

        //         finalArg = encodeSwapUniV3(
        //             canFail,
        //             pool,
        //             recipient,
        //             zeroForOne,
        //             amountSpecified,
        //             sqrtPriceLimitX96,
        //             result
        //         );

        //     }else if(actions[0] == Action.SwapUniV4) {
        //         (canFail,currency0,currency1, fee,tickSpacing, hook,
        //         zeroForOne, amountSpecified,sqrtPriceLimitX96, data) =
        //             abi.decode(datas[dataOffset],(bool, address, address, uint24,int24,address, bool,int256, uint160, bytes));

        //         SwapParams memory swapParams = SwapParams({
        //             zeroForOne: zeroForOne,
        //             amountSpecified: amountSpecified,
        //             sqrtPriceLimitX96: sqrtPriceLimitX96
        //         });

        //         finalArg = encodeSwapUniV4(
        //             canFail,
        //             currency0,
        //             currency1,
        //             fee,
        //             tickSpacing,
        //             hook,
        //             swapParams,
        //             result
        //         );
        //     }

        //     assembly {
        //         return(add(finalArg, 32), mload(finalArg))
        //     }
        // }

        assembly {
            return(add(result, 32), mload(result))
        }
    }

    function encodeSwapUniV1(
        bool canFail,
        address pair,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) public view returns (bytes memory) {
        Action action = Action.SwapUniV2;
        uint8 pairByteLen = byteLen(pair);
        uint8 amountInByteLen = byteLen(amountIn);
        uint8 amountOutByteLen = byteLen(amountOut);
        uint8 toByteLen = byteLen(to);

        bytes memory encoded = new bytes(
            6 + pairByteLen + amountInByteLen + amountOutByteLen + toByteLen
        ); // 6 = action + canFail + length*num

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, pairByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, pairByteLen)), pair)) // 左移 96位
            ptr := add(ptr, pairByteLen)

            mstore(ptr, shl(0xf8, amountInByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amountInByteLen)), amountIn))
            ptr := add(ptr, amountInByteLen)

            mstore(ptr, shl(0xf8, amountOutByteLen))
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(0x08, amountOutByteLen)), amountOut)
            )
            ptr := add(ptr, amountOutByteLen)

            mstore(ptr, shl(0xf8, toByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, toByteLen)), to))
        }

        return encoded;
    }

    function encodeSwapUniV2(
        bool canFail,
        address pair,
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) public view returns (bytes memory) {
        Action action = Action.SwapUniV2;
        uint8 pairByteLen = byteLen(pair);
        uint8 amount0OutByteLen = byteLen(amount0Out);
        uint8 amount1OutByteLen = byteLen(amount1Out);
        uint8 toByteLen = byteLen(to);
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            10 +
                pairByteLen +
                amount0OutByteLen +
                amount1OutByteLen +
                toByteLen +
                dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, pairByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, pairByteLen)), pair)) // 左移 96位
            ptr := add(ptr, pairByteLen)

            mstore(ptr, shl(0xf8, amount0OutByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(0x08, amount0OutByteLen)), amount0Out)
            )
            ptr := add(ptr, amount0OutByteLen)

            mstore(ptr, shl(0xf8, amount1OutByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(0x08, amount1OutByteLen)), amount1Out)
            )
            ptr := add(ptr, amount1OutByteLen)

            mstore(ptr, shl(0xf8, toByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, toByteLen)), to))
            ptr := add(ptr, toByteLen)

            mstore(ptr, shl(0xe0, dataByteLen)) // 多余字段
            ptr := add(ptr, 0x04)

            pop(
                staticcall(
                    gas(),
                    0x04,
                    add(data, 0x20),
                    dataByteLen,
                    ptr,
                    dataByteLen
                )
            )
        }

        return encoded;
    }

    function encodeSwapUniV2WithData(
        bool canFail,
        address pair,
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) public view returns (bytes memory) {
        Action action = Action.SwapUniV2;
        uint8 pairByteLen = byteLen(pair);
        uint8 amount0OutByteLen = byteLen(amount0Out);
        uint8 amount1OutByteLen = byteLen(amount1Out);
        uint8 toByteLen = byteLen(to);
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            10 +
                pairByteLen +
                amount0OutByteLen +
                amount1OutByteLen +
                toByteLen +
                dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, pairByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, pairByteLen)), pair)) // 左移 96位
            ptr := add(ptr, pairByteLen)

            mstore(ptr, shl(0xf8, amount0OutByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(0x08, amount0OutByteLen)), amount0Out)
            )
            ptr := add(ptr, amount0OutByteLen)

            mstore(ptr, shl(0xf8, amount1OutByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(0x08, amount1OutByteLen)), amount1Out)
            )
            ptr := add(ptr, amount1OutByteLen)

            mstore(ptr, shl(0xf8, toByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, toByteLen)), to))
            ptr := add(ptr, toByteLen)

            mstore(ptr, shl(0xe0, dataByteLen)) // 多余字段
            ptr := add(ptr, 0x04)

            pop(
                staticcall(
                    gas(),
                    0x04,
                    add(data, 0x20),
                    dataByteLen,
                    ptr,
                    dataByteLen
                )
            )
        }

        return encoded;
    }

    function encodeSwapUniV3(
        bool canFail,
        address pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes memory data
    ) public view returns (bytes memory) {
        Action action = Action.SwapUniV3;
        uint8 poolByteLen = byteLen(pool);
        uint8 recipientByteLen = byteLen(recipient);
        uint8 amountSpecifiedByteLen = byteLen(amountSpecified);
        uint8 sqrtPriceLimitX96ByteLen = byteLen(sqrtPriceLimitX96);
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            11 +
                poolByteLen +
                recipientByteLen +
                amountSpecifiedByteLen +
                sqrtPriceLimitX96ByteLen +
                dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, poolByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(poolByteLen, 0x08)), pool))
            ptr := add(ptr, poolByteLen)

            mstore(ptr, shl(0xf8, recipientByteLen))
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(recipientByteLen, 0x08)), recipient)
            )
            ptr := add(ptr, recipientByteLen)

            mstore(ptr, shl(0xf8, zeroForOne))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, amountSpecifiedByteLen))
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(
                    sub(0x0100, mul(amountSpecifiedByteLen, 0x08)),
                    amountSpecified
                )
            )
            ptr := add(ptr, amountSpecifiedByteLen)

            mstore(ptr, shl(0xf8, sqrtPriceLimitX96ByteLen))
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(
                    sub(0x0100, mul(sqrtPriceLimitX96ByteLen, 0x08)),
                    sqrtPriceLimitX96
                )
            )
            ptr := add(ptr, sqrtPriceLimitX96ByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))
            ptr := add(ptr, 0x04)

            pop(
                staticcall(
                    gas(),
                    0x04,
                    add(data, 0x20),
                    dataByteLen,
                    ptr,
                    dataByteLen
                )
            )
        }

        return encoded;
    }

    function encodeFlashUniV3(
        bool canFail,
        address pool,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes memory data
    ) public view returns (bytes memory) {
        Action action = Action.FlashUniV3;
        uint8 poolByteLen = byteLen(pool);
        uint8 recipientByteLen = byteLen(recipient);
        uint8 amount0ByteLen = byteLen(amount0);
        uint8 amount1ByteLen = byteLen(amount1);
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            10 +
                poolByteLen +
                recipientByteLen +
                amount0ByteLen +
                amount1ByteLen +
                dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, poolByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(poolByteLen, 0x08)), pool))
            ptr := add(ptr, poolByteLen)

            mstore(ptr, shl(0xf8, recipientByteLen))
            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(recipientByteLen, 0x08)), recipient)
            )
            ptr := add(ptr, recipientByteLen)

            mstore(ptr, shl(0xf8, amount0ByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(amount0ByteLen, 0x08)), amount0))
            ptr := add(ptr, amount0ByteLen)

            mstore(ptr, shl(0xf8, amount1ByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(amount1ByteLen, 0x08)), amount1))
            ptr := add(ptr, amount1ByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))
            ptr := add(ptr, 0x04)

            pop(
                staticcall(
                    gas(),
                    0x04,
                    add(data, 0x20),
                    dataByteLen,
                    ptr,
                    dataByteLen
                )
            )
        }

        return encoded;
    }

    // function encodeUniV4SwapAllInOne(
    //     address token0,
    //     address token1,
    //     uint24 fee,
    //     int24 tickSpacing,
    //     address hook,
    //     SwapParams memory swapParams,
    //     address to,
    //     bytes memory data
    // ) public view returns (bytes memory) {
    //     Action action = Action.SwapUniV4;
    //     uint8 token0ByteLen = byteLen(token0);
    //     uint8 token1ByteLen = byteLen(token1);
    //     uint8 hookByteLen = byteLen(hook);
    //     uint8 amountSpecifiedByteLen = byteLen(swapParams.amountSpecified);
    //     uint8 sqrtPriceLimitX96ByteLen = byteLen(swapParams.sqrtPriceLimitX96);
    //     uint8 toByteLen = byteLen(to);
    //     uint256 dataByteLen = data.length;

    //     bytes memory encoded = new bytes(
    //         18 + token0ByteLen + token1ByteLen + hookByteLen + amountSpecifiedByteLen
    //             + sqrtPriceLimitX96ByteLen + toByteLen + dataByteLen
    //     );

    //     assembly ("memory-safe") {
    //         let ptr := add(encoded, 0x20)

    //         mstore(ptr, shl(0xf8, action))
    //         ptr := add(ptr, 0x01)

    //         mstore(ptr, shl(0xf8, token0ByteLen))
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(token0ByteLen, 0x08)), token0))
    //         ptr := add(ptr, token0ByteLen)

    //         mstore(ptr, shl(0xf8, token1ByteLen))
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(token1ByteLen, 0x08)), token1))
    //         ptr := add(ptr, token1ByteLen)

    //         mstore(ptr, shl(0xe8, fee))
    //         ptr := add(ptr, 0x03)

    //         mstore(ptr, shl(0xe8, tickSpacing))
    //         ptr := add(ptr, 0x03)

    //         mstore(ptr, shl(0xf8, hookByteLen))
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(hookByteLen, 0x08)), hook))
    //         ptr := add(ptr, hookByteLen)

    //         // 访问 swapParams.zeroForOne (偏移量 0)
    //         let zeroForOne := mload(swapParams)
    //         mstore(ptr, shl(0xf8, zeroForOne))
    //         ptr := add(ptr, 0x01)

    //         // 访问 swapParams.amountSpecified (偏移量 32)
    //         let amountSpecified := mload(add(swapParams, 0x20))
    //         mstore(ptr, shl(0xf8, amountSpecifiedByteLen))
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(amountSpecifiedByteLen, 0x08)), amountSpecified))
    //         ptr := add(ptr, amountSpecifiedByteLen)

    //         // 访问 swapParams.sqrtPriceLimitX96 (偏移量 64)
    //         let sqrtPriceLimitX96 := mload(add(swapParams, 0x40))
    //         mstore(ptr, shl(0xf8, sqrtPriceLimitX96ByteLen))
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(sqrtPriceLimitX96ByteLen, 0x08)), sqrtPriceLimitX96))
    //         ptr := add(ptr, sqrtPriceLimitX96ByteLen)

    //         mstore(ptr, shl(0xf8, toByteLen))
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(toByteLen, 0x08)), to))
    //         ptr := add(ptr, toByteLen)

    //         mstore(ptr, shl(0xe0, dataByteLen))
    //         ptr := add(ptr, 0x04)

    //         pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))

    //         // mcopy(ptr, add(data, 0x20), dataByteLen)
    //     }

    //     // console.logBytes(encoded);

    //     return encoded;
    // }

    function encodeUniV4Unlock(
        bytes memory data
    ) internal view returns (bytes memory) {
        Action action = Action.UniV4Unlock;
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(5 + dataByteLen);

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xe0, dataByteLen)) // 多余字段
            ptr := add(ptr, 0x04)

            pop(
                staticcall(
                    gas(),
                    0x04,
                    add(data, 0x20),
                    dataByteLen,
                    ptr,
                    dataByteLen
                )
            )
        }

        return encoded;
    }

    // 会导致编译不通过
    // function encodeUniV4Swap(
    //         address currency0,
    //         address currency1,
    //         uint24 fee,
    //         int24 tickSpacing,
    //         address hook,
    //         bool zeroForOne,
    //         int256 amountSpecified,
    //         uint160 sqrtPX96,
    //         bytes memory data
    // ) public view returns (bytes memory) {
    //     Action action = Action.SwapUniV2;
    //     uint8 currency0ByteLen = byteLen(currency0);
    //     uint8 currency1ByteLen = byteLen(currency1);
    //     uint8 hookByteLen = byteLen(hook);
    //     uint8 amountSpecifiedByteLen = byteLen(amountSpecified);
    //     uint8 sqrtPX96ByteLen = byteLen(sqrtPX96);
    //     uint256 dataByteLen = data.length;

    //     bytes memory encoded = new bytes(
    //         17 + currency0ByteLen + currency1ByteLen + hookByteLen + amountSpecifiedByteLen + sqrtPX96ByteLen + dataByteLen
    //     );

    //     assembly ("memory-safe") {
    //         let ptr := add(encoded, 0x20)

    //         mstore(ptr, shl(0xf8, action))
    //         ptr := add(ptr, 0x01)

    //         mstore(ptr, shl(0xf8, currency0ByteLen))
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(0x08, currency0ByteLen)), currency0)) // 左移 96位
    //         ptr := add(ptr, currency0ByteLen)

    //         mstore(ptr, shl(0xf8, currency1ByteLen)) // 多余字段
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(0x08, currency1ByteLen)), currency1)) // 左移 96位
    //         ptr := add(ptr, currency1ByteLen)

    //         mstore(ptr, shl(0xe8, fee)) // 多余字段
    //         ptr := add(ptr, 0x03)

    //         mstore(ptr, shl(0xe8, tickSpacing)) // 多余字段
    //         ptr := add(ptr, 0x03)

    //         mstore(ptr, shl(0xf8, hookByteLen)) // 多余字段
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(0x08, hookByteLen)), hook)) // 左移 96位
    //         ptr := add(ptr, hookByteLen)

    //         mstore(ptr, shl(0xf8, zeroForOne))// 多余字段
    //         ptr := add(ptr, 0x01)

    //         mstore(ptr, shl(0xf8, amountSpecifiedByteLen)) // 多余字段
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(0x08, amountSpecifiedByteLen)), amountSpecified)) // 左移 96位
    //         ptr := add(ptr, amountSpecifiedByteLen)

    //         mstore(ptr, shl(0xf8, sqrtPX96ByteLen)) // 多余字段
    //         ptr := add(ptr, 0x01)
    //         mstore(ptr, shl(sub(0x0100, mul(0x08, sqrtPX96ByteLen)), sqrtPX96)) // 左移 96位
    //         ptr := add(ptr, sqrtPX96ByteLen)

    //         mstore(ptr, shl(0xe0, dataByteLen))// 多余字段
    //         ptr := add(ptr, 0x04)

    //         pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
    //     }

    //     return encoded;
    // }

    function encodeUniV4Sync(
        address currency
    ) public view returns (bytes memory) {
        Action action = Action.UniV4Sync;
        uint8 currencyByteLen = byteLen(currency);

        bytes memory encoded = new bytes(1 + 1 + currencyByteLen);

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, currencyByteLen)) // 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, currencyByteLen)), currency))
        }

        return encoded;
    }

    function encodeUniV4Settle() public view returns (bytes memory) {
        Action action = Action.UniV4Settle;

        bytes memory encoded = new bytes(1);

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)
            mstore(ptr, shl(0xf8, action))
        }

        return encoded;
    }

    function encodeUniV4Take(
        address currency,
        address to,
        uint256 amount
    ) public view returns (bytes memory) {
        Action action = Action.UniV4Take;
        uint8 currencyByteLen = byteLen(currency);
        uint8 toByteLen = byteLen(to);
        uint8 amountByteLen = byteLen(amount);

        bytes memory encoded = new bytes(
            4 + currencyByteLen + toByteLen + amountByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, currencyByteLen)) // 多余字段
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, currencyByteLen)), currency)) // 左移 96位
            ptr := add(ptr, currencyByteLen)

            mstore(ptr, shl(0xf8, toByteLen)) // 多余字段
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, toByteLen)), to)) // 左移 96位
            ptr := add(ptr, toByteLen)

            mstore(ptr, shl(0xf8, amountByteLen)) // 多余字段
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, amountByteLen)), amount)) // 左移 96位
        }

        return encoded;
    }

    function encodeSwapUniV4(
        bool canFail,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        address hook,
        SwapParams memory swapParams,
        bytes memory data
    ) public view returns (bytes memory) {
        Action action = Action.SwapUniV4;
        uint8 token0ByteLen = byteLen(token0);
        uint8 token1ByteLen = byteLen(token1);
        uint8 hookByteLen = byteLen(hook);
        uint8 amountSpecifiedByteLen = byteLen(swapParams.amountSpecified);
        uint8 sqrtPriceLimitX96ByteLen = byteLen(swapParams.sqrtPriceLimitX96);
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            18 +
                token0ByteLen +
                token1ByteLen +
                hookByteLen +
                amountSpecifiedByteLen +
                sqrtPriceLimitX96ByteLen +
                dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, token0ByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(token0ByteLen, 0x08)), token0))
            ptr := add(ptr, token0ByteLen)

            mstore(ptr, shl(0xf8, token1ByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(token1ByteLen, 0x08)), token1))
            ptr := add(ptr, token1ByteLen)

            mstore(ptr, shl(0xe8, fee))
            ptr := add(ptr, 0x03)

            mstore(ptr, shl(0xe8, tickSpacing))
            ptr := add(ptr, 0x03)

            mstore(ptr, shl(0xf8, hookByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(hookByteLen, 0x08)), hook))
            ptr := add(ptr, hookByteLen)

            // 访问 swapParams.zeroForOne (偏移量 0)
            let zeroForOne := mload(swapParams)
            mstore(ptr, shl(0xf8, zeroForOne))
            ptr := add(ptr, 0x01)

            // 访问 swapParams.amountSpecified (偏移量 32)
            let amountSpecified := mload(add(swapParams, 0x20))
            mstore(ptr, shl(0xf8, amountSpecifiedByteLen))
            ptr := add(ptr, 0x01)
            mstore(
                ptr,
                shl(
                    sub(0x0100, mul(amountSpecifiedByteLen, 0x08)),
                    amountSpecified
                )
            )
            ptr := add(ptr, amountSpecifiedByteLen)

            // 访问 swapParams.sqrtPriceLimitX96 (偏移量 64)
            let sqrtPriceLimitX96 := mload(add(swapParams, 0x40))
            mstore(ptr, shl(0xf8, sqrtPriceLimitX96ByteLen))
            ptr := add(ptr, 0x01)
            mstore(
                ptr,
                shl(
                    sub(0x0100, mul(sqrtPriceLimitX96ByteLen, 0x08)),
                    sqrtPriceLimitX96
                )
            )
            ptr := add(ptr, sqrtPriceLimitX96ByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))
            ptr := add(ptr, 0x04)

            pop(
                staticcall(
                    gas(),
                    0x04,
                    add(data, 0x20),
                    dataByteLen,
                    ptr,
                    dataByteLen
                )
            )

            // mcopy(ptr, add(data, 0x20), dataByteLen)
        }

        // console.logBytes(encoded);

        return encoded;
    }

    function encodeTransferERC20(
        bool canFail,
        address token,
        address receiver,
        uint256 amount
    ) public view returns (bytes memory) {
        Action action = Action.TransferERC20;
        uint8 tokenByteLen = byteLen(token);
        uint8 receiverByteLen = byteLen(receiver);
        uint8 amountByteLen = byteLen(amount);

        bytes memory encoded = new bytes(
            5 + tokenByteLen + receiverByteLen + amountByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, tokenByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, tokenByteLen)), token))

            ptr := add(ptr, tokenByteLen)

            mstore(ptr, shl(0xf8, receiverByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, receiverByteLen)), receiver))

            ptr := add(ptr, receiverByteLen)

            mstore(ptr, shl(0xf8, amountByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amountByteLen)), amount))
        }

        return encoded;
    }

    function encodeTransferFromERC20(
        bool canFail,
        address token,
        address sender,
        address receiver,
        uint256 amount
    ) public view returns (bytes memory) {
        Action action = Action.TransferFromERC20;
        uint8 tokenByteLen = byteLen(token);
        uint8 senderByteLen = byteLen(sender);
        uint8 receiverByteLen = byteLen(receiver);
        uint8 amountByteLen = byteLen(amount);

        bytes memory encoded = new bytes(
            6 + tokenByteLen + senderByteLen + receiverByteLen + amountByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, tokenByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, tokenByteLen)), token))

            ptr := add(ptr, tokenByteLen)

            mstore(ptr, shl(0xf8, senderByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, senderByteLen)), sender))

            ptr := add(ptr, senderByteLen)

            mstore(ptr, shl(0xf8, receiverByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, receiverByteLen)), receiver))

            ptr := add(ptr, receiverByteLen)

            mstore(ptr, shl(0xf8, amountByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amountByteLen)), amount))
        }

        return encoded;
    }

    function encodeTransferFromERC721(
        bool canFail,
        address token,
        address sender,
        address receiver,
        uint256 tokenId
    ) public view returns (bytes memory) {
        Action action = Action.TransferFromERC20;
        uint8 tokenByteLen = byteLen(token);
        uint8 senderByteLen = byteLen(sender);
        uint8 receiverByteLen = byteLen(receiver);
        uint8 tokenIdByteLen = byteLen(tokenId);

        bytes memory encoded = new bytes(
            6 + tokenByteLen + senderByteLen + receiverByteLen + tokenIdByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, tokenByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, tokenByteLen)), token))

            ptr := add(ptr, tokenByteLen)

            mstore(ptr, shl(0xf8, senderByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, senderByteLen)), sender))

            ptr := add(ptr, senderByteLen)

            mstore(ptr, shl(0xf8, receiverByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, receiverByteLen)), receiver))

            ptr := add(ptr, receiverByteLen)

            mstore(ptr, shl(0xf8, tokenIdByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, tokenIdByteLen)), tokenId))
        }

        return encoded;
    }

    function encodeTransferERC6909(
        bool canFail,
        address multitoken,
        address receiver,
        uint256 tokenId,
        uint256 amount
    ) public view returns (bytes memory) {
        Action action = Action.TransferERC6909;
        uint8 multitokenByteLen = byteLen(multitoken);
        uint8 receiverByteLen = byteLen(receiver);
        uint8 tokenIdByteLen = byteLen(tokenId);
        uint8 amountByteLen = byteLen(amount);

        bytes memory encoded = new bytes(
            6 +
                multitokenByteLen +
                receiverByteLen +
                tokenIdByteLen +
                amountByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, multitokenByteLen))

            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(0x08, multitokenByteLen)), multitoken)
            )

            ptr := add(ptr, multitokenByteLen)

            mstore(ptr, shl(0xf8, receiverByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, receiverByteLen)), receiver))

            ptr := add(ptr, receiverByteLen)

            mstore(ptr, shl(0xf8, tokenIdByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, tokenIdByteLen)), tokenId))

            ptr := add(ptr, tokenIdByteLen)

            mstore(ptr, shl(0xf8, amountByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amountByteLen)), amount))
        }

        return encoded;
    }

    function encodeTransferFromERC6909(
        bool canFail,
        address multitoken,
        address sender,
        address receiver,
        uint256 tokenId,
        uint256 amount
    ) public view returns (bytes memory) {
        Action action = Action.TransferFromERC6909;
        uint8 multitokenByteLen = byteLen(multitoken);
        uint8 senderByteLen = byteLen(sender);
        uint8 receiverByteLen = byteLen(receiver);
        uint8 tokenIdByteLen = byteLen(tokenId);
        uint8 amountByteLen = byteLen(amount);

        bytes memory encoded = new bytes(
            7 +
                multitokenByteLen +
                senderByteLen +
                receiverByteLen +
                tokenIdByteLen +
                amountByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, multitokenByteLen))

            ptr := add(ptr, 0x01)

            mstore(
                ptr,
                shl(sub(0x0100, mul(0x08, multitokenByteLen)), multitoken)
            )

            ptr := add(ptr, multitokenByteLen)

            mstore(ptr, shl(0xf8, senderByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, senderByteLen)), sender))

            ptr := add(ptr, senderByteLen)

            mstore(ptr, shl(0xf8, receiverByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, receiverByteLen)), receiver))

            ptr := add(ptr, receiverByteLen)

            mstore(ptr, shl(0xf8, tokenIdByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, tokenIdByteLen)), tokenId))

            ptr := add(ptr, tokenIdByteLen)

            mstore(ptr, shl(0xf8, amountByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amountByteLen)), amount))
        }

        return encoded;
    }

    function encodeDynCall(
        bool canFail,
        address target,
        uint256 value,
        bytes memory data
    ) public view returns (bytes memory) {
        Action action = Action.DynCall;
        uint8 targetByteLen = byteLen(target);
        uint8 valueByteLen = byteLen(value);
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            8 + targetByteLen + valueByteLen + dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, targetByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, targetByteLen)), target))
            ptr := add(ptr, targetByteLen)

            mstore(ptr, shl(0xf8, valueByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, valueByteLen)), value))
            ptr := add(ptr, valueByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))
            ptr := add(ptr, 0x04)

            pop(
                staticcall(
                    gas(),
                    0x04,
                    add(data, 0x20),
                    dataByteLen,
                    ptr,
                    dataByteLen
                )
            )
        }

        return encoded;
    }

    function byteLen(uint256 word) public view returns (uint8) {
        for (uint8 i = 32; i > 0; i--) {
            if (word >> ((i - 1) * 8) != 0) return i;
        }

        return 0;
    }

    function byteLen(address addr) public view returns (uint8) {
        uint160 word = uint160(addr);

        for (uint8 i = 20; i > 0; i--) {
            if (word >> ((i - 1) * 8) != 0) return i;
        }

        return 0;
    }

    function byteLen(int256 word) public view returns (uint8) {
        uint256 adjusted;

        if (word < 0) {
            adjusted = uint256(-word);
        } else {
            adjusted = uint256(word);
        }

        if (byteLen(adjusted) == 32) return 32;
        else return byteLen(adjusted << 1);
    }
}
