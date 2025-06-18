// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import { Action } from "src/types/Action.sol";
import { BytesCalldata } from "src/types/BytesCalldata.sol";

import { Error } from "src/types/Error.sol";
import { Ptr, findPtr } from "src/types/PayloadPointer.sol";
import { ERC20 } from "src/types/protocols/ERC20.sol";
import { ERC6909 } from "src/types/protocols/ERC6909.sol";
import { ERC721 } from "src/types/protocols/ERC721.sol";
import { UniV1Exchange } from "src/types/protocols/UniV1Exchange.sol";
import { UniV2Pair } from "src/types/protocols/UniV2Pair.sol";
import { UniV3Pool } from "src/types/protocols/UniV3Pool.sol";
import { WETH } from "src/types/protocols/WETH.sol";
import { dynCall } from "src/types/protocols/Dyn.sol";
import { BBCDecoder } from "src/util/BBCDecoder.sol";
import { SwapParams } from "src/types/protocols/UniV4Pool.sol";

contract LotusRouterEncoder {

    constructor(Action[] memory actions, bytes32[] memory data ){
        uint32 dataOffset = 0;
        bytes memory result = new bytes(0);

        bool firstActionIsV2V3 = false;

        if(actions[0] == Action.SwapUniV2 ){
            firstActionIsV2V3 = true;
            dataOffset = 5;

        }else if (actions[0] == Action.SwapUniV3) {
            firstActionIsV2V3 = true;
            dataOffset = 6;
        }

        // 如果第一个池是v2v3 那就用callback, 先跳过第一个action, 构造 data
        for (uint i = firstActionIsV2V3? 1:0; i < actions.length; i++) {
            Action action = actions[i];
            bytes memory encoded;

            if(action == Action.SwapUniV1) {
                encoded = encodeSwapUniV1(
                    uint256(data[dataOffset++]) != 0,
                    address(uint160(uint256(data[dataOffset++]))),
                    uint256(data[dataOffset++]),
                    uint256(data[dataOffset++]),
                    address(uint160(uint256(data[dataOffset++])))
                );
            }else if(action == Action.SwapUniV2) { 
                encoded = encodeSwapUniV2(
                    uint256(data[dataOffset++]) != 0,
                    address(uint160(uint256(data[dataOffset++]))),
                    uint256(data[dataOffset++]),
                    uint256(data[dataOffset++]),
                    address(uint160(uint256(data[dataOffset++]))),
                    ""
                );
            }else if(action == Action.SwapUniV3) { 
                encoded = encodeSwapUniV3(
                    uint256(data[dataOffset++]) != 0,
                    address(uint160(uint256(data[dataOffset++]))),
                    address(uint160(uint256(data[dataOffset++]))),
                    uint256(data[dataOffset++]) != 0,
                    int256(uint256(data[dataOffset++])),
                    uint160(uint256(data[dataOffset++])),
                    ""
                );
            }else if(action == Action.SwapUniV4) { 
                dataOffset += 6;
                SwapParams memory swapParams = SwapParams({
                    zeroForOne: uint256(data[dataOffset++]) != 0,
                    amountSpecified: int256(uint256(data[dataOffset++])),
                    sqrtPriceLimitX96: uint160(uint256(data[dataOffset++]))
                });
                dataOffset -= 9;

                encoded = encodeSwapUniV4(
                    uint256(data[dataOffset++]) != 0, //canFail
                    address(uint160(uint256(data[dataOffset++]))), //currency0
                    address(uint160(uint256(data[dataOffset++]))), //currency1
                    uint24(uint256(data[dataOffset++])), //fee
                    int24(int256(uint256(data[dataOffset++]))), //tickSpacing
                    address(uint160(uint256(data[dataOffset++]))), //hook
                    swapParams,
                    ""
                );
            }else if(action == Action.TransferERC20) { 
                // can,token,receiver,amount
                encoded = encodeTransferERC20(
                    uint256(data[dataOffset++]) != 0, 
                    address(uint160(uint256(data[dataOffset++]))),
                    address(uint160(uint256(data[dataOffset++]))),
                    uint256(data[dataOffset++])
                );
             
            }else if(action == Action.DepositWETH) { 
            }else if(action == Action.WithdrawWETH) { 
            }

            assembly {
                    let encodedLen := mload(encoded)
                    let resultPtr := add(add(result, 32), mload(result))
                    let encodedPtr := add(encoded, 32)
                    pop(staticcall(gas(), 0x04, encodedPtr, encodedLen, resultPtr, encodedLen))
                    mstore(result, add(mload(result), encodedLen))
            }
            
        }

        if(firstActionIsV2V3) {
            bytes memory finalArg = new bytes(0);
            dataOffset = 0;

            if(actions[0]==Action.SwapUniV2) {
                finalArg = encodeSwapUniV2(
                    uint256(data[dataOffset++]) != 0,
                    address(uint160(uint256(data[dataOffset++]))),
                    uint256(data[dataOffset++]),
                    uint256(data[dataOffset++]),
                    address(uint160(uint256(data[dataOffset++]))),
                    result
                );
            }else if(actions[0]==Action.SwapUniV3) {
                finalArg = encodeSwapUniV3(
                    uint256(data[dataOffset++]) != 0,
                    address(uint160(uint256(data[dataOffset++]))),
                    address(uint160(uint256(data[dataOffset++]))),
                    uint256(data[dataOffset++]) != 0,
                    int256(uint256(data[dataOffset++])),
                    uint160(uint256(data[dataOffset++])),
                    result
                );
            }

            assembly {
                return(add(finalArg, 32), mload(finalArg))
            }
        }

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

            mstore(ptr, shl(sub(0x0100, mul(0x08, amountOutByteLen)), amountOut))
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
            10 + pairByteLen + amount0OutByteLen + amount1OutByteLen + toByteLen + dataByteLen
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

            mstore(ptr, shl(0xf8, amount0OutByteLen))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amount0OutByteLen)), amount0Out))
            ptr := add(ptr, amount0OutByteLen)

            mstore(ptr, shl(0xf8, amount1OutByteLen))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amount1OutByteLen)), amount1Out))
            ptr := add(ptr, amount1OutByteLen)

            mstore(ptr, shl(0xf8, toByteLen))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, toByteLen)), to))
            ptr := add(ptr, toByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))// 多余字段
            ptr := add(ptr, 0x04)

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
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
            10 + pairByteLen + amount0OutByteLen + amount1OutByteLen + toByteLen + dataByteLen
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

            mstore(ptr, shl(0xf8, amount0OutByteLen))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amount0OutByteLen)), amount0Out))
            ptr := add(ptr, amount0OutByteLen)

            mstore(ptr, shl(0xf8, amount1OutByteLen))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, amount1OutByteLen)), amount1Out))
            ptr := add(ptr, amount1OutByteLen)

            mstore(ptr, shl(0xf8, toByteLen))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, toByteLen)), to))
            ptr := add(ptr, toByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))// 多余字段
            ptr := add(ptr, 0x04)

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
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
            11 + poolByteLen + recipientByteLen + amountSpecifiedByteLen + sqrtPriceLimitX96ByteLen
                + dataByteLen
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

            mstore(ptr, shl(sub(0x0100, mul(recipientByteLen, 0x08)), recipient))
            ptr := add(ptr, recipientByteLen)

            mstore(ptr, shl(0xf8, zeroForOne))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, amountSpecifiedByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(amountSpecifiedByteLen, 0x08)), amountSpecified))
            ptr := add(ptr, amountSpecifiedByteLen)

            mstore(ptr, shl(0xf8, sqrtPriceLimitX96ByteLen))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(sqrtPriceLimitX96ByteLen, 0x08)), sqrtPriceLimitX96))
            ptr := add(ptr, sqrtPriceLimitX96ByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))
            ptr := add(ptr, 0x04)

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
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
            10 + poolByteLen + recipientByteLen + amount0ByteLen + amount1ByteLen + dataByteLen
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

            mstore(ptr, shl(sub(0x0100, mul(recipientByteLen, 0x08)), recipient))
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

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
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
            18 + token0ByteLen + token1ByteLen + hookByteLen + amountSpecifiedByteLen
                + sqrtPriceLimitX96ByteLen + dataByteLen
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
            mstore(ptr, shl(sub(0x0100, mul(amountSpecifiedByteLen, 0x08)), amountSpecified))
            ptr := add(ptr, amountSpecifiedByteLen)

            // 访问 swapParams.sqrtPriceLimitX96 (偏移量 64)
            let sqrtPriceLimitX96 := mload(add(swapParams, 0x40))
            mstore(ptr, shl(0xf8, sqrtPriceLimitX96ByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(sqrtPriceLimitX96ByteLen, 0x08)), sqrtPriceLimitX96))
            ptr := add(ptr, sqrtPriceLimitX96ByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))
            ptr := add(ptr, 0x04)

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))

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

        bytes memory encoded = new bytes(5 + tokenByteLen + receiverByteLen + amountByteLen);

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

        bytes memory encoded =
            new bytes(6 + tokenByteLen + senderByteLen + receiverByteLen + amountByteLen);

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

        bytes memory encoded =
            new bytes(6 + tokenByteLen + senderByteLen + receiverByteLen + tokenIdByteLen);

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

        bytes memory encoded =
            new bytes(6 + multitokenByteLen + receiverByteLen + tokenIdByteLen + amountByteLen);

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, multitokenByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, multitokenByteLen)), multitoken))

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
            7 + multitokenByteLen + senderByteLen + receiverByteLen + tokenIdByteLen + amountByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, multitokenByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, multitokenByteLen)), multitoken))

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

    function encodeDepositWETH(
        bool canFail,
        address weth,
        uint256 value
    ) public view returns (bytes memory) {
        Action action = Action.DepositWETH;
        uint8 wethByteLen = byteLen(weth);
        uint8 valueByteLen = byteLen(value);

        bytes memory encoded = new bytes(4 + wethByteLen + valueByteLen);

        assembly {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, wethByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, wethByteLen)), weth))

            ptr := add(ptr, wethByteLen)

            mstore(ptr, shl(0xf8, valueByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, valueByteLen)), value))
        }

        return encoded;
    }

    function encodeWithdrawWETH(
        bool canFail,
        address weth,
        uint256 value
    ) public view returns (bytes memory) {
        Action action = Action.WithdrawWETH;
        uint8 wethByteLen = byteLen(weth);
        uint8 valueByteLen = byteLen(value);

        bytes memory encoded = new bytes(4 + wethByteLen + valueByteLen);

        assembly {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, wethByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, wethByteLen)), weth))

            ptr := add(ptr, wethByteLen)

            mstore(ptr, shl(0xf8, valueByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, valueByteLen)), value))
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

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
        }

        return encoded;
    }

    function byteLen(
        uint256 word
    ) public view returns (uint8) {
        for (uint8 i = 32; i > 0; i--) {
            if (word >> ((i - 1) * 8) != 0) return i;
        }

        return 0;
    }

    function byteLen(
        address addr
    ) public view returns (uint8) {
        uint160 word = uint160(addr);

        for (uint8 i = 20; i > 0; i--) {
            if (word >> ((i - 1) * 8) != 0) return i;
        }

        return 0;
    }

    function byteLen(
        int256 word
    ) public view returns (uint8) {
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