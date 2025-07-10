// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import { Action } from "src/types/Action.sol";
import { Error } from "src/types/Error.sol";

type Ptr is uint256;

using { nextAction } for Ptr global;

uint256 constant takeAction = 0x19ff8034;
uint256 constant uniswapV2Call = 0x10d1e85c;
uint256 constant uniswapV3SwapCallback = 0xfa461e33;
uint256 constant uniswapV3FlashCallback = 0xe9cbafb0;
uint256 constant uniswapV4UnlockCallback = 0x91dd7346;

uint256 constant pancakeCall = 0x84800812; //function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data)
uint256 constant elkCall = 0x33Ce117C; // elkCall

// ## Finds the Payload Pointer
//
// ### Returns
//
// - ptr: A pointer to the payload in calldata
//
// ### Reverts
//
// - If the selector does not match any expected ones.
//
// ### Notes
//
// For `callLotusRouter()`, the payload immediately follows the selector at
// index four (`0x04`).
//
// For `uniswapV2Call(address,uint256,uint256,bytes)`, the payload is in the
// fourth parameter, `bytes calldata data`, where the offset is at index 100,
// the length is at index 132, and the data itself is at index 164 (`0xa4`).
function findPtr() returns (Ptr) {
    uint256 selector = uint256(uint32(msg.sig));

    if (selector == takeAction) {
        return Ptr.wrap(0x04);
    } else if (selector == uniswapV2Call) {
        return Ptr.wrap(0xa4); // 0x60 + 0x44
        // return Ptr.wrap(0xa4); // 0x60 + 0x44
    } else if (selector == pancakeCall) {
        return Ptr.wrap(0xa4); // 0x60 + 0x44
    } else if (selector == elkCall) {
        return Ptr.wrap(0xa4); // 0x60 + 0x44
    } else if (selector == uniswapV3SwapCallback) {
        return Ptr.wrap(0x84); // 0x40 + 0x44
    } else if (selector == uniswapV4UnlockCallback) {
        // v4 调用unlock 会调用这个函数, 是交易的入口
        // assembly {
        //     let _calldatasize := calldatasize()
        //     _calldatasize := sub(_calldatasize, 0x44)

        //     calldatacopy(0x40, 0x44, _calldatasize)

        //     pop(call(gas(), 0x000000000004444c5dc75cB358380D2e3dE08A90, 0x00, 0x40, _calldatasize, 0x00, 0x00))

        //     stop()
        // }
        return Ptr.wrap(0x44);
    } else if (selector == uniswapV3FlashCallback) {
        return Ptr.wrap(0x84);
    } else {
        revert Error.UnexpectedEntryPoint();
    }
}

// ## Loads the Next Action from Calldata
//
// ## Parameters
//
// - ptr: The payload pointer
//
// ## Returns
//
// - ptr: The incremented payload pointer
// - action: The loaded action
//
// ## Notes
//
// The `ptr` parameter is incremented in place to allow continuous parsing.
function nextAction(
    Ptr ptr
) pure returns (Ptr, Action action) {
    assembly {
        action := shr(0xf8, calldataload(ptr))

        ptr := add(ptr, 0x01)
    }

    return (ptr, action);
}
