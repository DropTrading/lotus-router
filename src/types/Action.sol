// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

enum Action {
    Halt,
    SwapUniV2,
    SwapUniV3,
    FlashUniV3,
    TransferERC20,
    TransferFromERC20,
    TransferFromERC721,
    TransferERC6909,
    TransferFromERC6909,
    DepositWETH,
    WithdrawWETH
}
