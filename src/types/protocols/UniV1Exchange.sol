// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import { BytesCalldata } from "src/types/BytesCalldata.sol";

type UniV1Exchange is address;

using { ethToTokenTransferInput, tokenToEthTransferInput } for UniV1Exchange global;

uint256 constant ethToTokenTransferInputSelector = 0xad65d76d00000000000000000000000000000000000000000000000000000000;
uint256 constant tokenToEthTransferInputSelector = 0xd38d702900000000000000000000000000000000000000000000000000000000;

function ethToTokenTransferInput(UniV1Exchange pair,uint256 amount_in, uint256 min_tokens, address recipient) returns(bool success) {
    assembly ("memory-safe") {
        let fmp := mload(0x40)

        mstore(add(fmp, 0x00), ethToTokenTransferInputSelector)

        mstore(add(fmp, 0x04), min_tokens)
        mstore(add(fmp, 0x24), timestamp() )
        mstore(add(fmp, 0x44), recipient)

        success := call(gas(), pair, amount_in, fmp, 0x64, 0x00, 0x00)
    }
}

function tokenToEthTransferInput(UniV1Exchange pair,uint256 amount_in, uint256 min_tokens , address recipient ) returns (bool success) {
    assembly ("memory-safe") {
        let fmp := mload(0x40)

        mstore(add(fmp, 0x00), ethToTokenTransferInputSelector)

        mstore(add(fmp, 0x04), amount_in)
        mstore(add(fmp, 0x24), min_tokens)
        mstore(add(fmp, 0x44), timestamp())
        mstore(add(fmp, 0x64), recipient)

        success := call(gas(), pair, 0x00, fmp, 0x84, 0x00, 0x00)
    }
}



