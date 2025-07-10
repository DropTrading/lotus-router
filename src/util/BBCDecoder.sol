// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import {BytesCalldata} from "src/types/BytesCalldata.sol";
import {Ptr} from "src/types/PayloadPointer.sol";
import {ERC20} from "src/types/protocols/ERC20.sol";
import {ERC6909} from "src/types/protocols/ERC6909.sol";
import {ERC721} from "src/types/protocols/ERC721.sol";
import {UniV1Exchange} from "src/types/protocols/UniV1Exchange.sol";
import {UniV2Pair} from "src/types/protocols/UniV2Pair.sol";
import {UniV3Pool} from "src/types/protocols/UniV3Pool.sol";
import {WETH} from "src/types/protocols/WETH.sol";
import "forge-std/console.sol";
import {PoolKey,SwapParams} from "src/types/protocols/UniV4Pool.sol";

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
// We maintain a running pointer `Ptr`, which is incremented as parameters are
// parsed from calldata. This is because the encoding scheme is tightly packed
// such that the exact position of subsequent parameters is unknown at compile
// time. We do this to ensure tight calldata encoding, as callata is quite
// expensive.
library BBCDecoder {
    uint256 internal constant u8Shr = 0xf8;
    uint256 internal constant u24Shr = 0xe8;
    uint256 internal constant u32Shr = 0xe0;

    // ## Decode Uniswap V1 Swap
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - pair: The Uniswap V1 pair address.
    // - amountIn:
    // - amountOUt:
    // - to: The receiver of the swap output.
    function decodeSwapUniV1(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            UniV1Exchange exchange,
            bool ethForToken,
            uint256 amountIn,
            uint256 amountOut,
            address to
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            exchange := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            ethForToken := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amountIn := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amountOut := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            to := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode Uniswap V2 Swap
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - pair: The Uniswap V2 pair address.
    // - amount0Out: The expected output amount for token 0.
    // - amount1Out: The expected output amount for token 1.
    // - to: The receiver of the swap output.
    // - data: The arbitrary calldata for UniV2 callbacks, if any.
    function decodeSwapUniV2(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            UniV2Pair pair,
            uint256 amount0Out,
            uint256 amount1Out,
            address to,
            BytesCalldata data
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            pair := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount0Out := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount1Out := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            to := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u32Shr, calldataload(nextPtr))

            data := nextPtr

            nextPtr := add(nextPtr, 0x04)

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode Uniswap V3 Swap
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - pool: The Uniswap V3 pool address.
    // - recipient: The receiver of the swap output.
    // - zeroForOne: Direction of the trade; "true": zero for one, "false": one for zero.
    // - amountSpecified: The "exact" portion of the trade amount (More in Notes).
    // - sqrtPriceLimitX96: The Q64.96 representation of the price limit.
    // - data: The arbitrary calldata for UniV3 callbacks, if any.
    function decodeSwapUniV3(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            UniV3Pool pool,
            address recipient,
            bool zeroForOne,
            int256 amountSpecified,
            uint160 sqrtPriceLimitX96,
            BytesCalldata data
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            pool := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            recipient := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)

            zeroForOne := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amountSpecified := shr(nextBitShift, calldataload(nextPtr))
            amountSpecified := signextend(
                sub(nextByteLen, 0x01),
                amountSpecified
            )

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            sqrtPriceLimitX96 := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u32Shr, calldataload(nextPtr))

            data := nextPtr

            nextPtr := add(nextPtr, 0x04)

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode Uniswap V3 Flash Loan
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - pool: The Uniswap V3 pool address.
    // - recipient: The receiver of the flash output.
    // - amount0: The amount of Token 0 to flash.
    // - amount1: The amount of Token 1 to flash.
    // - data: The arbitrary calldata for UniV3 callbacks, if any.
    function decodeFlashUniV3(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            UniV3Pool pool,
            address recipient,
            uint256 amount0,
            uint256 amount1,
            BytesCalldata data
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            pool := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            recipient := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount0 := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount1 := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u32Shr, calldataload(nextPtr))

            data := nextPtr

            nextPtr := add(nextPtr, 0x04)

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    function decodeUniV4SwapAllInOne(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing,
            address hook,
            bool zeroForOne,
            int256 amountSpecified,
            uint160 sqrtPriceLimitX96,
            address to,
            BytesCalldata hookData
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            nextByteLen := shr(u8Shr, calldataload(nextPtr)) // +1
            nextPtr := add(nextPtr, 0x01)
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))

            token0 := shr(nextBitShift, calldataload(nextPtr)) // +nextByteLen
            nextPtr := add(nextPtr, nextByteLen)

            nextByteLen := shr(u8Shr, calldataload(nextPtr)) // +1
            nextPtr := add(nextPtr, 0x01)
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))

            token1 := shr(nextBitShift, calldataload(nextPtr)) // + nextByteLen
            nextPtr := add(nextPtr, nextByteLen)

            fee := shr(0xe8, calldataload(nextPtr)) // +3
            nextPtr := add(nextPtr, 0x03)
            nextBitShift := sub(0x0100, mul(0x08, 3))

            tickSpacing := shr(nextBitShift, calldataload(nextPtr)) // +3
            nextPtr := add(nextPtr, 0x03)
            nextBitShift := sub(0x0100, mul(0x08, 3))

            nextByteLen := shr(u8Shr, calldataload(nextPtr)) // +1
            nextPtr := add(nextPtr, 0x01)
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))

            hook := shr(nextBitShift, calldataload(nextPtr)) // +nextByteLen
            nextPtr := add(nextPtr, nextByteLen)

            zeroForOne := shr(u8Shr, calldataload(nextPtr)) // +1
            nextPtr := add(nextPtr, 0x01)

            nextByteLen := shr(u8Shr, calldataload(nextPtr)) // +1
            nextPtr := add(nextPtr, 0x01)
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))

            amountSpecified := shr(nextBitShift, calldataload(nextPtr)) // +nextByteLen
            nextPtr := add(nextPtr, nextByteLen)

            nextByteLen := shr(u8Shr, calldataload(nextPtr)) // +1
            nextPtr := add(nextPtr, 0x01)
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))

            sqrtPriceLimitX96 := shr(nextBitShift, calldataload(nextPtr)) // +nextByteLen
            nextPtr := add(nextPtr, nextByteLen)


            nextByteLen := shr(u8Shr, calldataload(nextPtr)) // +1
            nextPtr := add(nextPtr, 0x01)
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))

            to := shr(nextBitShift, calldataload(nextPtr)) // +nextByteLen
            nextPtr := add(nextPtr, nextByteLen)

            nextByteLen := shr(u32Shr, calldataload(nextPtr)) // +4

            hookData := nextPtr

            nextPtr := add(nextPtr, 0x04)
            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode ERC20 Transfer
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - token: The ERC20 address.
    // - receiver: The transfer receiver address.
    // - amount: The transfer amount.
    function decodeTransferERC20(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            ERC20 token,
            address receiver,
            uint256 amount
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            token := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            receiver := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode ERC20 TransferFrom
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - token: The ERC20 address.
    // - sender: The transfer sender address.
    // - receiver: The transfer receiver address.
    // - amount: The transfer amount.
    function decodeTransferFromERC20(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            ERC20 token,
            address sender,
            address receiver,
            uint256 amount
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            token := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            sender := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            receiver := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode ERC721 TransferFrom
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - token: The ERC721 address.
    // - sender: The transfer sender address.
    // - receiver: The transfer receiver address.
    // - tokenId: The token ID to transfer.
    function decodeTransferFromERC721(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            ERC721 token,
            address sender,
            address receiver,
            uint256 tokenId
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            token := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            sender := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            receiver := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            tokenId := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode ERC6909 Transfer
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - multitoken: The ERC6909 address.
    // - receiver: The transfer receiver address.
    // - amount: The amount to transfer.
    // - tokenId: The token ID to transfer.
    function decodeTransferERC6909(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            ERC6909 multitoken,
            address receiver,
            uint256 tokenId,
            uint256 amount
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            multitoken := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            receiver := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            tokenId := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode ERC6909 TransferFrom
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - multitoken: The ERC6909 address.
    // - sender: The transfer sender address.
    // - receiver: The transfer receiver address.
    // - amount: The amount to transfer.
    // - tokenId: The token ID to transfer.
    function decodeTransferFromERC6909(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            ERC6909 multitoken,
            address sender,
            address receiver,
            uint256 tokenId,
            uint256 amount
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            multitoken := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            sender := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            receiver := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            tokenId := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode WETH Deposit
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - value: The amount to deposit.
    function decodeDepositWETH(
        Ptr ptr
    )
        internal
        pure
        returns (Ptr nextPtr, bool canFail, uint256 value)
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            value := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode WETH Withdrawal
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - value: The amount to withdraw.
    function decodeWithdrawWETH(
        Ptr ptr
    )
        internal
        pure
        returns (Ptr nextPtr, bool canFail, uint256 value)
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            value := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    // ## Decode Dynamic Contract Call
    //
    // ### Parameters
    //
    // - ptr: The running pointer.
    //
    // ### Returns
    //
    // - nextPtr: The updated pointer.
    // - canFail: Boolean indicating whether the call can fail.
    // - target: The call target address.
    // - value: The call value.
    // - data: The call payload.
    function decodeDynCall(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            bool canFail,
            address target,
            uint256 value,
            BytesCalldata data
        )
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            canFail := shr(u8Shr, calldataload(nextPtr))

            nextPtr := add(nextPtr, 0x01)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            target := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            value := shr(nextBitShift, calldataload(nextPtr))

            nextPtr := add(nextPtr, nextByteLen)
            nextByteLen := shr(u32Shr, calldataload(nextPtr))

            data := nextPtr

            nextPtr := add(nextPtr, 0x04)

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    function decodeUniV4Unlock(
        Ptr ptr
    ) internal pure returns (Ptr nextPtr, BytesCalldata data) {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            nextByteLen := shr(u32Shr, calldataload(nextPtr))

            data := nextPtr

            nextPtr := add(nextPtr, 0x04)

            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    function decodeUniV4Swap(
        Ptr ptr
    )
        internal
        pure
        returns (
            Ptr nextPtr,
            // address currency0,
            // address currency1,
            // uint24 fee,
            // int24 tickSpacing,
            // address hook,
            // bool zeroForOne,
            // int256 amountSpecified,
            // uint160 sqrtPX96,
            PoolKey memory poolKey,
            SwapParams memory swapParams,
            BytesCalldata data
        )
    {
        assembly("memory-safe") {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            // nextByteLen := shr(u8Shr, calldataload(nextPtr))
            // nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            // nextPtr := add(nextPtr, 0x01)

            // currency0 := shr(nextBitShift, calldataload(nextPtr))
            // nextPtr := add(nextPtr, nextByteLen)

            // nextByteLen := shr(u8Shr, calldataload(nextPtr))
            // nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            // nextPtr := add(nextPtr, 0x01)

            // currency1 := shr(nextBitShift, calldataload(nextPtr))
            // nextPtr := add(nextPtr, nextByteLen)

            // fee := shr(0xe8, calldataload(nextPtr))
            // nextPtr := add(nextPtr, 0x03)

            // tickSpacing := shr(0xe8, calldataload(nextPtr))
            // nextPtr := add(nextPtr, 0x03)

            // nextByteLen := shr(u8Shr, calldataload(nextPtr))
            // nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            // nextPtr := add(nextPtr, 0x01)

            // hook := shr(nextBitShift, calldataload(nextPtr))
            // nextPtr := add(nextPtr, nextByteLen)

            // zeroForOne := shr(u8Shr, calldataload(nextPtr))
            // nextPtr := add(nextPtr, 0x01)

            // nextByteLen := shr(u8Shr, calldataload(nextPtr))
            // nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            // amountSpecified := shr(nextBitShift, calldataload(nextPtr))
            // nextPtr := add(nextPtr, nextByteLen)

            // nextByteLen := shr(u8Shr, calldataload(nextPtr))
            // nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            // sqrtPX96 := shr(nextBitShift, calldataload(nextPtr))
            // nextPtr := add(nextPtr, nextByteLen)

            // nextByteLen := shr(u32Shr, calldataload(nextPtr))
            // data := nextPtr
            // nextPtr := add(nextPtr, 0x04)
            // nextPtr := add(nextPtr, nextByteLen)

            // 解析 currency0
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)
            mstore(poolKey, shr(nextBitShift, calldataload(nextPtr))) // currency0
            nextPtr := add(nextPtr, nextByteLen)

            // 解析 currency1  
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)
            mstore(add(poolKey, 0x20), shr(nextBitShift, calldataload(nextPtr))) // currency1
            nextPtr := add(nextPtr, nextByteLen)

            // 解析 fee
            mstore(add(poolKey, 0x40), shr(0xe8, calldataload(nextPtr))) // fee
            nextPtr := add(nextPtr, 0x03)

            // 解析 tickSpacing
            mstore(add(poolKey, 0x43), shr(0xe8, calldataload(nextPtr))) // tickSpacing
            nextPtr := add(nextPtr, 0x03)

            // 解析 hook
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)
            mstore(add(poolKey, 0x46), shr(nextBitShift, calldataload(nextPtr))) // hook
            nextPtr := add(nextPtr, nextByteLen)

            // 解析 swapParams.zeroForOne
            mstore(swapParams, shr(u8Shr, calldataload(nextPtr))) // zeroForOne
            nextPtr := add(nextPtr, 0x01)

            // 解析 swapParams.amountSpecified
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)
            mstore(add(swapParams, 0x20), shr(nextBitShift, calldataload(nextPtr))) // amountSpecified
            nextPtr := add(nextPtr, nextByteLen)

            // 解析 swapParams.sqrtPriceLimitX96
            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)
            mstore(add(swapParams, 0x40), shr(nextBitShift, calldataload(nextPtr))) // sqrtPriceLimitX96
            nextPtr := add(nextPtr, nextByteLen)

            // 解析 data
            nextByteLen := shr(u32Shr, calldataload(nextPtr))
            data := nextPtr
            nextPtr := add(nextPtr, 0x04)
            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    function decodeUniV4Sync(
        Ptr ptr
    ) internal pure returns (Ptr nextPtr, address currency) {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            currency := shr(nextBitShift, calldataload(nextPtr))
            nextPtr := add(nextPtr, nextByteLen)
        }
    }

    function decodeUniV4Settle(Ptr ptr) internal pure returns (Ptr nextPtr) {}

    function decodeUniV4Take(
        Ptr ptr
    )
        internal
        pure
        returns (Ptr nextPtr, address currency, address to, uint256 amount)
    {
        assembly {
            let nextByteLen, nextBitShift
            nextPtr := ptr

            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            currency := shr(nextBitShift, calldataload(nextPtr))
            nextPtr := add(nextPtr, nextByteLen)

            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            to := shr(nextBitShift, calldataload(nextPtr))
            nextPtr := add(nextPtr, nextByteLen)

            nextByteLen := shr(u8Shr, calldataload(nextPtr))
            nextBitShift := sub(0x0100, mul(0x08, nextByteLen))
            nextPtr := add(nextPtr, 0x01)

            amount := shr(nextBitShift, calldataload(nextPtr))
            nextPtr := add(nextPtr, nextByteLen)
        }
    }
}
