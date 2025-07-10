// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

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
    UniV4PoolManager v4Pool = UniV4PoolManager.wrap(0x000000000004444c5dc75cB358380D2e3dE08A90);
    WETH weth = WETH.wrap(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    
    // 硬编码的 owner 地址常量
    address constant HARDCODED_OWNER = 0x000000000AA26c45bCCff01AEEA193F430F389bB;

    // 使用常量的硬编码版本
    // 检查
    function checkOrigin() internal view {
        assembly {
            let originValue := origin()
            if iszero(eq(originValue, HARDCODED_OWNER)) {
                // error selector: bytes4(keccak256("OriginMustBeOwner()")) = 0x7e9d5c2b
                mstore(0x00, 0xd1bfd81d00000000000000000000000000000000000000000000000000000000)
                revert(0x00, 4)
            }
        }
    }

    function erc20Withdraw(address token, address receiver, uint256 amount) external  {
        checkOrigin();

        ERC20.wrap(token).transfer(receiver,amount);
    }

    function ethWithdraw(address receiver, uint amount) external {
        checkOrigin();
        (bool success, ) = receiver.call{value:amount}("");
        require(success, "ETF"); // eth transfer failed.
    }

    // ## Fallback Function
    //
    // This contains all of the Lotus Router's execution logic.
    //
    // We use the fallback function to eschew Solidity's ABI encoding scheme.
    // Documentation is be provided for interfacing with this safely.
    fallback() external payable {
        // checkOrigin(); // 每次fallback执行权限检查

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

            if (action == Action.SwapUniV1) { // V1 swap
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

                // sqrtPrice 可以阉割掉
                if(sqrtPriceLimitX96 == 0) {
                    sqrtPriceLimitX96 = zeroForOne?  4295128739+1 : 1461446703485210103287273052203988822378723970342-1 ;
                }

                success = pool.swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)
                    || canFail;
            } else if (action == Action.UniV4SwapAllInOne) { // V4 swap     预期是由unlock调用
                BytesCalldata hookData;
                address token0;
                address token1;
                uint24 fee;
                int24 tickSpacing;
                address hook;
                bool zeroForOne;
                int256 amountSpecified;
                address to; // swap的代币转到哪
                uint160 sqrtPriceLimitX96;

                (   ptr,
                    token0,
                    token1,
                    fee,
                    tickSpacing,
                    hook,
                    zeroForOne,
                    amountSpecified,
                    sqrtPriceLimitX96,
                    to,
                    hookData
                ) = BBCDecoder.decodeUniV4SwapAllInOne(ptr);

                if(sqrtPriceLimitX96 == 0) {
                    sqrtPriceLimitX96 = zeroForOne? 4295128739+1: 1461446703485210103287273052203988822378723970342-1;
                }


                if(to == address(0)) {
                    to = address(this);
                }

                success = v4Pool.swapAllInOne( 
                    token0,
                    token1,
                    fee,
                    tickSpacing,
                    hook,
                    zeroForOne,
                    amountSpecified,
                    sqrtPriceLimitX96,
                    to,
                    hookData);
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
                uint256 value;

                (ptr, canFail, value) = BBCDecoder.decodeDepositWETH(ptr);

                success = weth.deposit(value) || canFail;
            } else if (action == Action.WithdrawWETH) {
                bool canFail;
                uint256 value;

                (ptr, canFail, value) = BBCDecoder.decodeWithdrawWETH(ptr);

                success = weth.withdraw(value) || canFail;
            } else if (action == Action.DynCall) {
                bool canFail;
                address target;
                uint256 value;
                BytesCalldata data;

                (ptr, canFail, target, value, data) = BBCDecoder.decodeDynCall(ptr);

                success = dynCall(target, value, data) || canFail;
            } else if (action == Action.UniV4Unlock) {
                BytesCalldata data;
                (ptr, data ) = BBCDecoder.decodeUniV4Unlock(ptr);

                success = v4Pool.unlock(data);
            } else if (action == Action.UniV4Sync) {

                address currency;
                (ptr, currency) = BBCDecoder.decodeUniV4Sync(ptr);

                v4Pool.sync(currency);

            } else if (action == Action.UniV4Swap) {
                
                // address currency0;
                // address currency1;
                // uint24 fee;
                // int24 tickSpacing;
                // address hook;

                // bool zeroForOne;
                // int256 amountSpecified;
                // uint160 sqrtPX96;
                BytesCalldata hookData;
                // PoolKey memory pk;
                // SwapParams memory sp;

                // (ptr, currency0, currency1, fee, tickSpacing, hook, zeroForOne, amountSpecified, sqrtPX96, hookData) = BBCDecoder.decodeUniV4Swap(ptr);
                // (ptr, pk,sp, hookData) = BBCDecoder.decodeUniV4Swap(ptr);

            } else if (action == Action.UniV4Settle) {
                v4Pool.settle();
            } else if (action == Action.UniV4Take) {
                address currency;
                address to;
                uint256 amount;
                (ptr, currency,to,amount) = BBCDecoder.decodeUniV4Take(ptr);

                success = v4Pool.take(currency,to,amount);
            }else if (action == Action.Halt) { // 中断
                assembly {
                    stop()
                }
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
