// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import { Action } from "src/types/Action.sol";

import {SwapParams, PoolKey , Currency, IHooks} from "src/types/protocols/UniV4Pool.sol";
import "forge-std/console.sol";


// ## Decoder
//
// Inspired by the calldata schema of BigBrainChad.eth
//
// ### Encoding Overview
//
// Statically sized calldata arguments of 8 bits or less are encoded in place.
//
// Statically sized calldata arguments of 9 to 256 bits are prefixed with their
// byte length (as an 8 bit integer) followed by the argument, compacted to its
// byte length. This is to handle the common case of the majority of bits being
// unoccupied.
//
// Dynamically sized calldata arguments are prefixed with a 32 bit integer
// indicating its byte length, followed by the bytes themselves. This is worth
// exploring in the future as to whether or not the upper bits of the byte
// length are unoccupied enough to justify an encoding as mentioned in the
// statically sized calldata arguments above.
//
// ### Notes
//
// This encoder, while in the source directory of the Lotus Router and its
// libraries, is not rigorously optimized, as the encoding scheme is meant to
// reduce the cost of the smart contract entry point, given the unusually high
// cost per byte of calldata. This is largely in service of testing libraries
// and more offchain periphery will be developed in the future to ensure users
// may interface with the Lotus Router in a reasonably safe way.
//
// Also, the encoder largely uses assembly nonetheless, as Solidity does not
// support fully dependent types, which would allow for run-time
// parameterization of value byte lengths.
library BBCEncoder {

    function encodeSwapUniV1(
        bool canFail,
        address pair,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) internal view returns (bytes memory) {
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
    ) internal view returns (bytes memory) {
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
    ) internal view returns (bytes memory) {
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
    ) internal view returns (bytes memory) {
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

    function encodeTransferERC20(
        bool canFail,
        address token,
        address receiver,
        uint256 amount
    ) internal pure returns (bytes memory) {
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
    ) internal pure returns (bytes memory) {
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
    ) internal pure returns (bytes memory) {
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
    ) internal pure returns (bytes memory) {
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
    ) internal pure returns (bytes memory) {
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
        uint256 value
    ) internal pure returns (bytes memory) {
        Action action = Action.DepositWETH;
        uint8 valueByteLen = byteLen(value);

        bytes memory encoded = new bytes(4 + valueByteLen);

        assembly {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, valueByteLen))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, valueByteLen)), value))
        }

        return encoded;
    }

    function encodeWithdrawWETH(
        bool canFail,
        uint256 value
    ) internal pure returns (bytes memory) {
        Action action = Action.WithdrawWETH;
        uint8 valueByteLen = byteLen(value);

        bytes memory encoded = new bytes(4 + valueByteLen);

        assembly {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))

            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, canFail))

            ptr := add(ptr, 0x01)

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
    ) internal view returns (bytes memory) {
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
    ) internal pure returns (uint8) {
        for (uint8 i = 32; i > 0; i--) {
            if (word >> ((i - 1) * 8) != 0) return i;
        }

        return 0;
    }

    function byteLen(
        address addr
    ) internal pure returns (uint8) {
        uint160 word = uint160(addr);

        for (uint8 i = 20; i > 0; i--) {
            if (word >> ((i - 1) * 8) != 0) return i;
        }

        return 0;
    }

    function byteLen(
        int256 word
    ) internal pure returns (uint8) {
        uint256 adjusted;

        if (word < 0) {
            adjusted = uint256(-word);
        } else {
            adjusted = uint256(word);
        }

        if (byteLen(adjusted) == 32) return 32;
        else return byteLen(adjusted << 1);
    }


    function encodeUniV4PoolKey(
        PoolKey memory pk
    )internal view returns (bytes memory encoded, uint16 len) {
        address token0 = Currency.unwrap(pk.currency0);
        console.log(token0);
        address token1 = Currency.unwrap(pk.currency1);
        address hooks = IHooks.unwrap(pk.hooks);
        uint8 token0ByteLen = byteLen(token0);
        uint8 token1ByteLen = byteLen(token1);

        uint8 hooksByteLen = byteLen(hooks);
        uint24 fee = pk.fee;
        int24 tickSpacing = pk.tickSpacing;

        len = 9 + token0ByteLen + token1ByteLen + hooksByteLen;

        encoded = new bytes( len);

        assembly {
            let ptr := add(encoded, 0x20)

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

            mstore(ptr, shl(0xf8, hooksByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(hooksByteLen, 0x08)), hooks))
            // ptr := add(ptr, hooksByteLen)


        }

        // return ;
    }


    function encodeUniV4SwapParams(
        SwapParams memory sp
    )internal view returns (bytes memory encoded, uint16 len) {
        uint8 amountSpecifiedByteLen = byteLen(sp.amountSpecified);
        uint8 sqrtPriceLimitX96ByteLen = byteLen(sp.sqrtPriceLimitX96);
        len = 3 + amountSpecifiedByteLen + sqrtPriceLimitX96ByteLen;

        bool zfo = sp.zeroForOne;
        int256 amountSpecified = sp.amountSpecified;
        uint160 sqrtP = sp.sqrtPriceLimitX96;

        encoded = new bytes(len);

        assembly {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, zfo))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, amountSpecifiedByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(amountSpecifiedByteLen, 0x08)), amountSpecified))
            ptr := add(ptr, amountSpecifiedByteLen)

            mstore(ptr, shl(0xf8, sqrtPriceLimitX96ByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(sqrtPriceLimitX96ByteLen, 0x08)), sqrtP))
            // ptr := add(ptr, sqrtPriceLimitX96ByteLen)
        }

        // return ;
    }

    function encodeUniV4SwapAllInOne(
        bytes memory data
    ) internal view returns (bytes memory) {
        Action action = Action.UniV4SwapAllInOne;

        ( address token0, address token1, uint24 fee, int24 tickSpacing, address hooks,
        bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, address to, bytes memory hookData) = 
                    abi.decode(data ,(address, address, uint24,int24,address, bool,int256, uint160,address, bytes));

        PoolKey memory pk = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks.wrap(hooks)
        });

        ( bytes memory pkdata ,uint16 pklen)= encodeUniV4PoolKey(pk);
        console.logBytes(pkdata);
        console.log(pklen);

        SwapParams memory sp = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        ( bytes memory spdata , uint16 splen)= encodeUniV4SwapParams(sp);
   
        uint8 toByteLen = byteLen(to);
        uint256 hookDataByteLen = hookData.length;

        bytes memory encoded = new bytes(
            18 + pklen+ splen + toByteLen + hookDataByteLen
        );


        assembly {
            let ptr := add(encoded, 0x20)
            let pkptr := add(pkdata, 0x20)
            let spptr := add(spdata, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mcopy(ptr, pkptr, mul(pklen,0x08) )
            ptr := add(ptr, pklen) 

            mcopy(ptr, spptr, mul(splen,0x08) )
            ptr := add(ptr, splen) 

            mstore(ptr, shl(0xf8, toByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr,  to)
            mstore(ptr, shl(sub(0x0100, mul(toByteLen, 0x08)), to))
            ptr := add(ptr, toByteLen)

            mstore(ptr, shl(0xe0, hookDataByteLen))
            ptr := add(ptr, 0x04)

            pop(staticcall(gas(), 0x04, add(hookData, 0x20), hookDataByteLen, ptr, hookDataByteLen))
        }

        return encoded;
    }

    function encodeUniV4Unlock(
        bytes memory data
    ) internal view returns (bytes memory) {
        Action action = Action.UniV4Unlock;
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            5 + dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xe0, dataByteLen))// 多余字段
            ptr := add(ptr, 0x04)

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
        }

        return encoded;
    }

    function encodeUniV4Swap(
            address currency0,
            address currency1,
            uint24 fee,
            int24 tickSpacing,
            address hook,
            bool zeroForOne,
            int256 amountSpecified,
            uint160 sqrtPX96,
            bytes memory data
    ) internal view returns (bytes memory) {
        Action action = Action.SwapUniV2;
        uint8 currency0ByteLen = byteLen(currency0);
        uint8 currency1ByteLen = byteLen(currency1);
        uint8 hookByteLen = byteLen(hook);
        uint8 amountSpecifiedByteLen = byteLen(amountSpecified);
        uint8 sqrtPX96ByteLen = byteLen(sqrtPX96);
        uint256 dataByteLen = data.length;

        bytes memory encoded = new bytes(
            17 + currency0ByteLen + currency1ByteLen + hookByteLen + amountSpecifiedByteLen + sqrtPX96ByteLen + dataByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, currency0ByteLen))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, currency0ByteLen)), currency0)) // 左移 96位
            ptr := add(ptr, currency0ByteLen)
            
            
            
            mstore(ptr, shl(0xf8, currency1ByteLen)) // 多余字段
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, currency1ByteLen)), currency1)) // 左移 96位
            ptr := add(ptr, currency1ByteLen)

            mstore(ptr, shl(0xe8, fee)) // 多余字段
            ptr := add(ptr, 0x03)

            mstore(ptr, shl(0xe8, tickSpacing)) // 多余字段
            ptr := add(ptr, 0x03)

            mstore(ptr, shl(0xf8, hookByteLen)) // 多余字段
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, hookByteLen)), hook)) // 左移 96位
            ptr := add(ptr, hookByteLen)

            mstore(ptr, shl(0xf8, zeroForOne))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, amountSpecifiedByteLen)) // 多余字段
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, amountSpecifiedByteLen)), amountSpecified)) // 左移 96位
            ptr := add(ptr, amountSpecifiedByteLen)


            mstore(ptr, shl(0xf8, sqrtPX96ByteLen)) // 多余字段
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(sub(0x0100, mul(0x08, sqrtPX96ByteLen)), sqrtPX96)) // 左移 96位
            ptr := add(ptr, sqrtPX96ByteLen)

            mstore(ptr, shl(0xe0, dataByteLen))// 多余字段
            ptr := add(ptr, 0x04)

            pop(staticcall(gas(), 0x04, add(data, 0x20), dataByteLen, ptr, dataByteLen))
        }

        return encoded;
    }

    function encodeUniV4Sync(
        address currency
    ) internal view returns (bytes memory) {
        Action action = Action.UniV4Sync;
        uint8 currencyByteLen = byteLen(currency);

        bytes memory encoded = new bytes(
            1 + 1 + currencyByteLen
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)

            mstore(ptr, shl(0xf8, action))
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(0xf8, currencyByteLen))// 多余字段
            ptr := add(ptr, 0x01)

            mstore(ptr, shl(sub(0x0100, mul(0x08, currencyByteLen)), currency))
        }

        return encoded;
    }

    function encodeUniV4Settle(
    ) internal view returns (bytes memory) {
        Action action = Action.UniV4Settle;

        bytes memory encoded = new bytes(
            1
        );

        assembly ("memory-safe") {
            let ptr := add(encoded, 0x20)
            mstore(ptr, shl(0xf8, action))
        }

        return encoded;
    }

    function encodeUniV4Take(
        address currency, address to, uint256 amount
    ) internal view returns (bytes memory) {
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
}
