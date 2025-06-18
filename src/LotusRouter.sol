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
import { UniV4PoolManager, SwapParams, PoolKey ,Currency, IHooks, BalanceDelta} from "src/types/protocols/UniV4Pool.sol";

import { WETH } from "src/types/protocols/WETH.sol";
import { dynCall } from "src/types/protocols/Dyn.sol";
import { BBCDecoder } from "src/util/BBCDecoder.sol";

contract LotusRouter {

    // constant
    UniV4PoolManager v4Pool = UniV4PoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);


    // ## Fallback Function
    //
    // This contains all of the Lotus Router's execution logic.
    //
    // We use the fallback function to eschew Solidity's ABI encoding scheme.
    // Documentation is be provided for interfacing with this safely.
    fallback() external payable {

        // findPtr 已经处理了callback,callback内的偏移已经调整
        // callback 只能触发一次，且必须是第一个指令
        // uniswapV2Call
        // uniswapV3SwapCallback
        // uniswapV3FlashCallback
        Ptr ptr = findPtr(); // 获取要执行的payload的offset

        Action action;
        bool success = true;
        while (success) {
            (ptr, action) = ptr.nextAction();

            if (action == Action.Halt) { // 中断
                assembly {
                    stop()
                }
            } else if (action == Action.SwapUniV1) { // V1 swap
                bool canFail;
                UniV1Exchange exchange;
                bool ethForToken; // 表示是否是 eth到token
                uint256 amountIn;
                uint256 amountOut;
                address to;

                (ptr, canFail, exchange, ethForToken, amountIn, amountOut, to ) =
                    BBCDecoder.decodeSwapUniV1(ptr);
                
                if(ethForToken){
                    success = exchange.ethToTokenTransferInput(amountIn, amountOut, to);
                }else{
                    success = exchange.tokenToEthTransferInput(amountIn, amountOut, to);
                }

            } else if (action == Action.SwapUniV2) { // V2 swap
                bool canFail;
                UniV2Pair pair;
                uint256 amount0Out;
                uint256 amount1Out;
                address to;
                BytesCalldata data;

                (ptr, canFail, pair, amount0Out, amount1Out, to, data) =
                    BBCDecoder.decodeSwapUniV2(ptr);

                success = pair.swap(amount0Out, amount1Out, to, data) || canFail;
            } else if (action == Action.SwapUniV3) { // V3 swap
                bool canFail;
                UniV3Pool pool;
                address recipient;
                bool zeroForOne;
                int256 amountSpecified;
                uint160 sqrtPriceLimitX96;
                BytesCalldata data;

                (
                    ptr,
                    canFail,
                    pool,
                    recipient,
                    zeroForOne,
                    amountSpecified,
                    sqrtPriceLimitX96,
                    data
                ) = BBCDecoder.decodeSwapUniV3(ptr);

                success = pool.swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)
                    || canFail;
            } else if (action == Action.SwapUniV4) { // V4 swap
                bool canFail;
                BytesCalldata data;
                address token0;
                address token1;
                uint24 fee;
                int24 tickSpacing;
                address hook;
                bool zeroForOne;
                int256 amountSpecified;
                uint160 sqrtPriceLimitX96;

                (   ptr,
                    canFail,
                    token0,
                    token1,
                    fee,
                    tickSpacing,
                    hook,
                    zeroForOne,
                    amountSpecified,
                    sqrtPriceLimitX96,
                    data
                ) = BBCDecoder.decodeSwapUniV4(ptr);

                success = v4Pool.swap( 
                    token0,
                    token1,
                    fee,
                    tickSpacing,
                    hook,
                    zeroForOne,
                    amountSpecified,
                    sqrtPriceLimitX96,
                    data)
                 || canFail;
            } else if (action == Action.FlashUniV3) {
                bool canFail;
                UniV3Pool pool;
                address recipient;
                uint256 amount0;
                uint256 amount1;
                BytesCalldata data;

                (ptr, canFail, pool, recipient, amount0, amount1, data) =
                    BBCDecoder.decodeFlashUniV3(ptr);

                success = pool.flash(recipient, amount0, amount1, data) || canFail;
            } else if (action == Action.TransferERC20) {
                bool canFail;
                ERC20 token;
                address receiver;
                uint256 amount;

                (ptr, canFail, token, receiver, amount) = BBCDecoder.decodeTransferERC20(ptr);

                success = token.transfer(receiver, amount) || canFail;
            } else if (action == Action.TransferFromERC20) {
                bool canFail;
                ERC20 token;
                address sender;
                address receiver;
                uint256 amount;

                (ptr, canFail, token, sender, receiver, amount) =
                    BBCDecoder.decodeTransferFromERC20(ptr);

                success = token.transferFrom(sender, receiver, amount) || canFail;
            } else if (action == Action.TransferFromERC721) {
                bool canFail;
                ERC721 token;
                address sender;
                address receiver;
                uint256 amount;

                (ptr, canFail, token, sender, receiver, amount) =
                    BBCDecoder.decodeTransferFromERC721(ptr);

                success = token.transferFrom(sender, receiver, amount) || canFail;
            } else if (action == Action.TransferERC6909) {
                bool canFail;
                ERC6909 multitoken;
                address receiver;
                uint256 tokenId;
                uint256 amount;

                (ptr, canFail, multitoken, receiver, tokenId, amount) =
                    BBCDecoder.decodeTransferERC6909(ptr);

                success = multitoken.transfer(receiver, tokenId, amount) || canFail;
            } else if (action == Action.TransferFromERC6909) {
                bool canFail;
                ERC6909 multitoken;
                address sender;
                address receiver;
                uint256 tokenId;
                uint256 amount;

                (ptr, canFail, multitoken, sender, receiver, tokenId, amount) =
                    BBCDecoder.decodeTransferFromERC6909(ptr);

                success = multitoken.transferFrom(sender, receiver, tokenId, amount) || canFail;
            } else if (action == Action.DepositWETH) {
                bool canFail;
                WETH weth;
                uint256 value;

                (ptr, canFail, weth, value) = BBCDecoder.decodeDepositWETH(ptr);

                success = weth.deposit(value) || canFail;
            } else if (action == Action.WithdrawWETH) {
                bool canFail;
                WETH weth;
                uint256 value;

                (ptr, canFail, weth, value) = BBCDecoder.decodeWithdrawWETH(ptr);

                success = weth.withdraw(value) || canFail;
            } else if (action == Action.DynCall) {
                bool canFail;
                address target;
                uint256 value;
                BytesCalldata data;

                (ptr, canFail, target, value, data) = BBCDecoder.decodeDynCall(ptr);

                success = dynCall(target, value, data) || canFail;
            } else {
                success = false;
            }
        }

        revert Error.CallFailure();
    }

    // ## Receiver Function
    //
    // This triggers when this contract is called with no calldata. It takes no
    // action, it only returns gracefully.
    receive() external payable { }
}
