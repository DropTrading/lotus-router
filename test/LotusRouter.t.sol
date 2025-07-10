// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import { Test } from "lib/forge-std/src/Test.sol";

import { ERC20Mock } from "test/mock/ERC20Mock.sol";
import {BalanceDelta} from "src/types/protocols/BalanceDelta.sol";

import { ERC6909Mock } from "test/mock/ERC6909Mock.sol";
import { ERC721Mock } from "test/mock/ERC721Mock.sol";
import { UniV2PairMock } from "test/mock/UniV2PairMock.sol";
import { UniV3PoolMock } from "test/mock/UniV3PoolMock.sol";
import { WETHMock, wethBytecode } from "test/mock/WETHMock.sol";
import { DynTargetMock } from "test/mock/DynTargetMock.sol";
import {IERC20} from "test/interfaces/IERC20.sol";
import "forge-std/console.sol";

import { LotusRouter } from "src/LotusRouter.sol";
import { BBCEncoder } from "src/util/BBCEncoder.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

function takeAction(LotusRouter lotus, bytes memory data) returns (bool success) {
    bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

    (success,) = address(lotus).call(payload);
}

function takeActionWithValue(
    LotusRouter lotus,
    uint256 value,
    bytes memory data
) returns (bool success) {
    bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

    (success,) = address(lotus).call{ value: value }(payload);
}

contract LotusRouterTest is Test {
    using { takeAction, takeActionWithValue } for LotusRouter;

    LotusRouter lotus;
    UniV2PairMock univ2_0;
    UniV2PairMock univ2_1;
    UniV3PoolMock univ3_0;
    UniV3PoolMock univ3_1;
    ERC20Mock erc20_0;
    ERC20Mock erc20_1;
    ERC721Mock erc721_0;
    ERC721Mock erc721_1;
    ERC6909Mock erc6909_0;
    ERC6909Mock erc6909_1;
    WETHMock weth;
    DynTargetMock dynTarget_0;
    DynTargetMock dynTarget_1;

    function setUp() public {
        lotus = new LotusRouter();
        univ2_0 = new UniV2PairMock();
        univ2_1 = new UniV2PairMock();
        univ3_0 = new UniV3PoolMock();
        univ3_1 = new UniV3PoolMock();
        erc20_0 = new ERC20Mock();
        erc20_1 = new ERC20Mock();
        erc721_0 = new ERC721Mock();
        erc721_1 = new ERC721Mock();
        erc6909_0 = new ERC6909Mock();
        erc6909_1 = new ERC6909Mock();
        weth = new WETHMock();
        dynTarget_0 = new DynTargetMock();
        dynTarget_1 = new DynTargetMock();
    }

    // -- UNIV2 ------------------------------------------------------------------------------------

    function testSwapUniV2Single() public {
        bool canFail = false;
        uint256 amount0Out = 0x01;
        uint256 amount1Out = 0x02;
        address to = address(0xaaaa);
        bytes memory data = hex"bbbb";

        vm.expectCall(
            address(univ2_0), abi.encodeCall(UniV2PairMock.swap, (amount0Out, amount1Out, to, data))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV2(canFail, address(univ2_0), amount0Out, amount1Out, to, data)
        );

        assertTrue(success);
    }

    function testSwapUniV2SingleThrows() public {
        bool canFail = false;
        uint256 amount0Out = 0x01;
        uint256 amount1Out = 0x02;
        address to = address(0xaaaa);
        bytes memory data = hex"bbbb";

        univ2_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV2(canFail, address(univ2_0), amount0Out, amount1Out, to, data)
        );

        assertFalse(success);
    }

    function testFuzzSwapUniV2Single(
        bool canFail,
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) public {
        vm.expectCall(
            address(univ2_0), abi.encodeCall(UniV2PairMock.swap, (amount0Out, amount1Out, to, data))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV2(canFail, address(univ2_0), amount0Out, amount1Out, to, data)
        );

        assertTrue(success || canFail);
    }

    function testSwapUniV2Chain() public {
        bool canFail = false;

        uint256 amount0Out_0 = 0x01;
        uint256 amount1Out_0 = 0x02;
        address to_0 = address(0xaaaa);
        bytes memory data_0 = hex"bbbb";

        uint256 amount0Out_1 = 0x03;
        uint256 amount1Out_1 = 0x04;
        address to_1 = address(0xcccc);
        bytes memory data_1 = hex"dddd";

        vm.expectCall(
            address(univ2_0),
            abi.encodeCall(UniV2PairMock.swap, (amount0Out_0, amount1Out_0, to_0, data_0))
        );

        vm.expectCall(
            address(univ2_1),
            abi.encodeCall(UniV2PairMock.swap, (amount0Out_1, amount1Out_1, to_1, data_1))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeSwapUniV2(
                    canFail, address(univ2_0), amount0Out_0, amount1Out_0, to_0, data_0
                ),
                BBCEncoder.encodeSwapUniV2(
                    canFail, address(univ2_1), amount0Out_1, amount1Out_1, to_1, data_1
                )
            )
        );

        assertTrue(success);
    }

    function testSwapUniV2ChainThrows() public {
        bool canFail = false;

        uint256 amount0Out_0 = 0x01;
        uint256 amount1Out_0 = 0x02;
        address to_0 = address(0xaaaa);
        bytes memory data_0 = hex"bbbb";

        uint256 amount0Out_1 = 0x03;
        uint256 amount1Out_1 = 0x04;
        address to_1 = address(0xcccc);
        bytes memory data_1 = hex"dddd";

        univ2_0.setShouldThrow(true);

        // expect call `0` times, since the univ2_0 market failure should short
        // circuit this
        vm.expectCall(
            address(univ2_1),
            abi.encodeCall(UniV2PairMock.swap, (amount0Out_1, amount1Out_1, to_1, data_1)),
            0
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeSwapUniV2(
                    canFail, address(univ2_0), amount0Out_0, amount1Out_0, to_0, data_0
                ),
                BBCEncoder.encodeSwapUniV2(
                    canFail, address(univ2_1), amount0Out_1, amount1Out_1, to_1, data_1
                )
            )
        );

        assertFalse(success);
    }

    function testFuzzSwapUniV2Chain(
        uint256 amount0Out_0,
        uint256 amount1Out_0,
        bytes memory data_0,
        uint256 amount0Out_1,
        uint256 amount1Out_1,
        bytes memory data_1
    ) public {
        // smth's up w the fuzzer; vm.expectCall fails, vm.expectEmit does not..
        // all data's the same tho?
        vm.expectEmit(true, true, true, true, address(univ2_0));
        emit UniV2PairMock.Swap(amount0Out_0, amount1Out_0, address(univ2_1), data_0);

        vm.expectEmit(true, true, true, true, address(univ2_1));
        emit UniV2PairMock.Swap(amount0Out_1, amount1Out_1, address(lotus), data_1);

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeSwapUniV2(
                    false, address(univ2_0), amount0Out_0, amount1Out_0, address(univ2_1), data_0
                ),
                BBCEncoder.encodeSwapUniV2(
                    false, address(univ2_1), amount0Out_1, amount1Out_1, address(lotus), data_1
                )
            )
        );

        assertTrue(success);
    }

    function testSwapUniV2Recurse() public {
        bool canFail = false;
        uint256 amount0Out = 0x01;
        uint256 amount1Out = 0x02;
        address to = address(lotus);
        bytes memory data = hex"00";

        univ2_0.setDoCallback(true);

        vm.expectCall(
            address(univ2_0), abi.encodeCall(UniV2PairMock.swap, (amount0Out, amount1Out, to, data))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV2(canFail, address(univ2_0), amount0Out, amount1Out, to, data)
        );

        assertTrue(success);
    }

    // -- UNIV3 ------------------------------------------------------------------------------------

    function testSwapUniV3Single() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        bool zeroForOne = true;
        int256 amountSpecified = 0x02;
        uint160 sqrtPriceLimitX96 = 0x03;
        bytes memory data = hex"deadbeef";

        vm.expectCall(
            address(univ3_0),
            abi.encodeCall(
                UniV3PoolMock.swap,
                (recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)
            )
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                data
            )
        );

        assertTrue(success);
    }

    function testSwapUniV3NegativeSingle() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        bool zeroForOne = true;
        int256 amountSpecified = -0x02;
        uint160 sqrtPriceLimitX96 = 0x03;
        bytes memory data = hex"deadbeef";

        vm.expectCall(
            address(univ3_0),
            abi.encodeCall(
                UniV3PoolMock.swap,
                (recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)
            )
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                data
            )
        );

        assertTrue(success);
    }

    function testSwapUniV3ThrowsSingle() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        bool zeroForOne = true;
        int256 amountSpecified = -0x02;
        uint160 sqrtPriceLimitX96 = 0x03;
        bytes memory data = hex"deadbeef";

        univ3_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                data
            )
        );

        assertFalse(success);
    }

    function testSwapUniV3Recurse() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        bool zeroForOne = true;
        int256 amountSpecified = 0x02;
        uint160 sqrtPriceLimitX96 = 0x03;
        bytes memory data = hex"deadbeef";

        bytes memory innerPayload = BBCEncoder.encodeSwapUniV3(
            canFail,
            address(univ3_1),
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );

        univ3_0.setDoCallback(true);

        vm.expectCall(
            address(univ3_0),
            abi.encodeCall(
                UniV3PoolMock.swap,
                (recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, innerPayload)
            )
        );

        vm.expectCall(
            address(univ3_1),
            abi.encodeCall(
                UniV3PoolMock.swap,
                (recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)
            )
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                innerPayload
            )
        );

        assertTrue(success);
    }

    function testFuzzSwapUniV3Single(
        bool shouldThrow,
        bool canFail,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes memory data
    ) public {
        assumeReasonableInt256(amountSpecified);

        univ3_0.setShouldThrow(shouldThrow);

        if (!shouldThrow || canFail) {
            vm.expectCall(
                address(univ3_0),
                abi.encodeCall(
                    UniV3PoolMock.swap,
                    (recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)
                )
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                data
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    function testSwapUniV3RecurseFirstThrows() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        bool zeroForOne = true;
        int256 amountSpecified = 0x02;
        uint160 sqrtPriceLimitX96 = 0x03;
        bytes memory data = hex"deadbeef";

        univ3_0.setShouldThrow(true);
        univ3_0.setDoCallback(true);

        bytes memory innerPayload = BBCEncoder.encodeSwapUniV3(
            canFail,
            address(univ3_1),
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                innerPayload
            )
        );

        assertFalse(success);
    }

    function testSwapUniV3RecurseSecondThrows() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        bool zeroForOne = true;
        int256 amountSpecified = 0x02;
        uint160 sqrtPriceLimitX96 = 0x03;
        bytes memory data = hex"deadbeef";

        univ3_0.setDoCallback(true);
        univ3_1.setShouldThrow(true);

        bytes memory innerPayload = BBCEncoder.encodeSwapUniV3(
            canFail,
            address(univ3_1),
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                innerPayload
            )
        );

        assertFalse(success);
    }

    function testFuzzSwapUniV3Recurse(
        bool shouldThrow,
        bool canFail,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes memory data
    ) public {
        assumeReasonableInt256(amountSpecified);

        univ3_0.setDoCallback(true);
        univ3_0.setShouldThrow(shouldThrow);

        bytes memory innerPayload = BBCEncoder.encodeSwapUniV3(
            canFail,
            address(univ3_1),
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );

        if (!shouldThrow || canFail) {
            vm.expectCall(
                address(univ3_0),
                abi.encodeCall(
                    UniV3PoolMock.swap,
                    (recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, innerPayload)
                )
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeSwapUniV3(
                canFail,
                address(univ3_0),
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                innerPayload
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    function testFlashUniV3Single() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        uint256 amount0 = 0x45;
        uint256 amount1 = 0x46;
        bytes memory data = hex"deadbeef";

        vm.expectCall(
            address(univ3_0),
            abi.encodeCall(UniV3PoolMock.flash, (recipient, amount0, amount1, data))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeFlashUniV3(
                canFail, address(univ3_0), recipient, amount0, amount1, data
            )
        );

        assertTrue(success);
    }

    function testFlashUniV3SingleThrows() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        uint256 amount0 = 0x45;
        uint256 amount1 = 0x46;
        bytes memory data = hex"deadbeef";

        univ3_0.setShouldThrow(true);

        vm.expectCall(
            address(univ3_0),
            abi.encodeCall(UniV3PoolMock.flash, (recipient, amount0, amount1, data))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeFlashUniV3(
                canFail, address(univ3_0), recipient, amount0, amount1, data
            )
        );

        assertFalse(success);
    }

    function testFuzzFlashUniV3Single(
        bool shouldThrow,
        bool canFail,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes memory data
    ) public {
        univ3_0.setShouldThrow(shouldThrow);

        if (!shouldThrow || canFail) {
            vm.expectCall(
                address(univ3_0),
                abi.encodeCall(UniV3PoolMock.flash, (recipient, amount0, amount1, data))
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeFlashUniV3(
                canFail, address(univ3_0), recipient, amount0, amount1, data
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    function testFlashUniV3Recurse() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        uint256 amount0 = 0x45;
        uint256 amount1 = 0x46;
        bytes memory data = hex"deadbeef";

        univ3_0.setDoCallback(true);

        bytes memory innerPayload = BBCEncoder.encodeFlashUniV3(
            canFail, address(univ3_1), recipient, amount0, amount1, data
        );

        vm.expectCall(
            address(univ3_0),
            abi.encodeCall(UniV3PoolMock.flash, (recipient, amount0, amount1, innerPayload))
        );

        vm.expectCall(
            address(univ3_1),
            abi.encodeCall(UniV3PoolMock.flash, (recipient, amount0, amount1, data))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeFlashUniV3(
                canFail, address(univ3_0), recipient, amount0, amount1, innerPayload
            )
        );

        assertTrue(success);
    }

    function testFlashUniV3RecurseThrows() public {
        bool canFail = false;
        address recipient = address(0xaabbccdd);
        uint256 amount0 = 0x45;
        uint256 amount1 = 0x46;
        bytes memory data = hex"deadbeef";

        univ3_0.setDoCallback(true);
        univ3_0.setShouldThrow(true);

        bytes memory innerPayload = BBCEncoder.encodeFlashUniV3(
            canFail, address(univ3_1), recipient, amount0, amount1, data
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeFlashUniV3(
                canFail, address(univ3_0), recipient, amount0, amount1, innerPayload
            )
        );

        assertFalse(success);
    }

    function testFuzzFlashUniV3Recurse(
        bool shouldThrow,
        bool canFail,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes memory data
    ) public {
        bytes memory innerPayload = BBCEncoder.encodeFlashUniV3(
            canFail, address(univ3_1), recipient, amount0, amount1, data
        );

        univ3_0.setDoCallback(true);
        univ3_0.setShouldThrow(shouldThrow);

        if (!shouldThrow || canFail) {
            vm.expectCall(
                address(univ3_0),
                abi.encodeCall(UniV3PoolMock.flash, (recipient, amount0, amount1, innerPayload))
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeFlashUniV3(
                canFail, address(univ3_0), recipient, amount0, amount1, innerPayload
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    // -- ERC20 ------------------------------------------------------------------------------------

    function testTransferERC20Single() public {
        bool canFail = false;
        address receiver = address(0xaabbccdd);
        uint256 amount = 0x02;

        vm.expectCall(address(erc20_0), abi.encodeCall(ERC20Mock.transfer, (receiver, amount)));

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver, amount)
        );

        assertTrue(success);
    }

    function testTransferERC20SingleReturnsNothing() public {
        bool canFail = false;
        address receiver = address(0xaabbccdd);
        uint256 amount = 0x02;

        erc20_0.setShouldReturnAnything(false);

        vm.expectCall(address(erc20_0), abi.encodeCall(ERC20Mock.transfer, (receiver, amount)));

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver, amount)
        );

        assertTrue(success);
    }

    function testTransferERC20SingleThrows() public {
        bool canFail = false;
        address receiver = address(0xaabbccdd);
        uint256 amount = 0x02;

        erc20_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver, amount)
        );

        assertFalse(success);
    }

    function testTransferERC20SingleReturnsFalse() public {
        bool canFail = false;
        address receiver = address(0xaabbccdd);
        uint256 amount = 0x02;

        erc20_0.setResult(false);

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver, amount)
        );

        assertFalse(success);
    }

    function testFuzzTransferERC20Single(
        bool canFail,
        bool shouldReturnAnything,
        bool shouldThrow,
        bool result,
        address receiver,
        uint256 amount
    ) public {
        erc20_0.setShouldReturnAnything(shouldReturnAnything);
        erc20_0.setShouldThrow(shouldThrow);
        erc20_0.setResult(result);

        bool callSucceeds = !shouldThrow && (result || !shouldReturnAnything) || canFail;

        if (callSucceeds) {
            vm.expectCall(address(erc20_0), abi.encodeCall(ERC20Mock.transfer, (receiver, amount)));
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver, amount)
        );

        assertEq(success, callSucceeds);
    }

    function testTransferERC20Chain() public {
        bool canFail = false;

        address receiver_0 = address(0xaabbccdd);
        uint256 amount_0 = 0x02;

        address receiver_1 = address(0xeeffaabb);
        uint256 amount_1 = 0x04;

        vm.expectCall(address(erc20_0), abi.encodeCall(ERC20Mock.transfer, (receiver_0, amount_0)));

        vm.expectCall(address(erc20_1), abi.encodeCall(ERC20Mock.transfer, (receiver_1, amount_1)));

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver_0, amount_0),
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_1), receiver_1, amount_1)
            )
        );

        assertTrue(success);
    }

    function testTransferERC20ChainReturnsNothing() public {
        bool canFail = false;

        address receiver_0 = address(0xaabbccdd);
        uint256 amount_0 = 0x02;

        address receiver_1 = address(0xeeffaabb);
        uint256 amount_1 = 0x04;

        erc20_0.setShouldReturnAnything(false);
        erc20_1.setShouldReturnAnything(false);

        vm.expectCall(address(erc20_0), abi.encodeCall(ERC20Mock.transfer, (receiver_0, amount_0)));

        vm.expectCall(address(erc20_1), abi.encodeCall(ERC20Mock.transfer, (receiver_1, amount_1)));

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver_0, amount_0),
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_1), receiver_1, amount_1)
            )
        );

        assertTrue(success);
    }

    function testTransferERC20ChainFirstThrows() public {
        bool canFail = false;

        address receiver_0 = address(0xaabbccdd);
        uint256 amount_0 = 0x02;

        address receiver_1 = address(0xeeffaabb);
        uint256 amount_1 = 0x04;

        erc20_0.setShouldThrow(true);

        vm.expectCall(
            address(erc20_1), abi.encodeCall(ERC20Mock.transfer, (receiver_1, amount_1)), 0
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver_0, amount_0),
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_1), receiver_1, amount_1)
            )
        );

        assertFalse(success);
    }

    function testTransferERC20ChainSecondThrows() public {
        bool canFail = false;

        address receiver_0 = address(0xaabbccdd);
        uint256 amount_0 = 0x02;

        address receiver_1 = address(0xeeffaabb);
        uint256 amount_1 = 0x04;

        erc20_1.setShouldThrow(true);

        vm.expectCall(address(erc20_0), abi.encodeCall(ERC20Mock.transfer, (receiver_0, amount_0)));

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver_0, amount_0),
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_1), receiver_1, amount_1)
            )
        );

        assertFalse(success);
    }

    function testFuzzTransferERC20Chain(
        bool canFail,
        bool shouldReturnAnything,
        bool shouldThrow,
        bool result,
        address receiver,
        uint256 amount
    ) public {
        erc20_0.setShouldReturnAnything(shouldReturnAnything);
        erc20_0.setShouldThrow(shouldThrow);
        erc20_0.setResult(result);

        erc20_0.setShouldReturnAnything(shouldReturnAnything);
        erc20_0.setShouldThrow(shouldThrow);
        erc20_0.setResult(result);

        bool callSucceeds = !shouldThrow && (result || !shouldReturnAnything) || canFail;

        if (callSucceeds) {
            vm.expectCall(address(erc20_0), abi.encodeCall(ERC20Mock.transfer, (receiver, amount)));

            vm.expectCall(address(erc20_1), abi.encodeCall(ERC20Mock.transfer, (receiver, amount)));
        }

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_0), receiver, amount),
                BBCEncoder.encodeTransferERC20(canFail, address(erc20_1), receiver, amount)
            )
        );

        assertEq(success, callSucceeds);
    }

    function testTransferFromERC20Single() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 amount = 0x02;

        vm.expectCall(
            address(erc20_0), abi.encodeCall(ERC20Mock.transferFrom, (sender, receiver, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC20(canFail, address(erc20_0), sender, receiver, amount)
        );

        assertTrue(success);
    }

    function testTransferFromERC20SingleReturnsNothing() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 amount = 0x02;

        erc20_0.setShouldReturnAnything(false);

        vm.expectCall(
            address(erc20_0), abi.encodeCall(ERC20Mock.transferFrom, (sender, receiver, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC20(canFail, address(erc20_0), sender, receiver, amount)
        );

        assertTrue(success);
    }

    function testTransferFromERC20SingleThrows() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 amount = 0x02;

        erc20_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC20(canFail, address(erc20_0), sender, receiver, amount)
        );

        assertFalse(success);
    }

    function testTransferFromERC20SingleReturnsFalse() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 amount = 0x02;

        erc20_0.setResult(false);

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC20(canFail, address(erc20_0), sender, receiver, amount)
        );

        assertFalse(success);
    }

    function testFuzzTransferFromERC20Single(
        bool canFail,
        bool shouldReturnAnything,
        bool shouldThrow,
        bool result,
        address sender,
        address receiver,
        uint256 amount
    ) public {
        erc20_0.setShouldReturnAnything(shouldReturnAnything);
        erc20_0.setShouldThrow(shouldThrow);
        erc20_0.setResult(result);

        bool callSucceeds = (!shouldThrow && (result || !shouldReturnAnything)) || canFail;

        if (callSucceeds) {
            vm.expectCall(
                address(erc20_0), abi.encodeCall(ERC20Mock.transferFrom, (sender, receiver, amount))
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC20(canFail, address(erc20_0), sender, receiver, amount)
        );

        assertEq(success, callSucceeds);
    }

    function testTransferFromERC20Chain() public {
        bool canFail = false;

        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 amount_0 = 0x02;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 amount_1 = 0x04;

        vm.expectCall(
            address(erc20_0),
            abi.encodeCall(ERC20Mock.transferFrom, (sender_0, receiver_0, amount_0))
        );

        vm.expectCall(
            address(erc20_1),
            abi.encodeCall(ERC20Mock.transferFrom, (sender_1, receiver_1, amount_1))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_0), sender_0, receiver_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_1), sender_1, receiver_1, amount_1
                )
            )
        );

        assertTrue(success);
    }

    function testTransferFromERC20ChainReturnsNothing() public {
        bool canFail = false;

        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 amount_0 = 0x02;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 amount_1 = 0x04;

        erc20_0.setShouldReturnAnything(false);
        erc20_1.setShouldReturnAnything(false);

        vm.expectCall(
            address(erc20_0),
            abi.encodeCall(ERC20Mock.transferFrom, (sender_0, receiver_0, amount_0))
        );

        vm.expectCall(
            address(erc20_1),
            abi.encodeCall(ERC20Mock.transferFrom, (sender_1, receiver_1, amount_1))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_0), sender_0, receiver_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_1), sender_1, receiver_1, amount_1
                )
            )
        );

        assertTrue(success);
    }

    function testTransferFromERC20ChainFirstThrows() public {
        bool canFail = false;

        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 amount_0 = 0x02;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 amount_1 = 0x04;

        erc20_0.setShouldThrow(true);

        vm.expectCall(
            address(erc20_1), abi.encodeCall(ERC20Mock.transferFrom, (sender_1, receiver_1, amount_1)),
            0
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_0), sender_0, receiver_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_1), sender_1, receiver_1, amount_1
                )
            )
        );

        assertFalse(success);
    }

    function testTransferFromERC20ChainSecondThrows() public {
        bool canFail = false;

        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 amount_0 = 0x02;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 amount_1 = 0x04;

        erc20_1.setShouldThrow(true);

        vm.expectCall(
            address(erc20_0),
            abi.encodeCall(ERC20Mock.transferFrom, (sender_0, receiver_0, amount_0))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_0), sender_0, receiver_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_1), sender_1, receiver_1, amount_1
                )
            )
        );

        assertFalse(success);
    }

    function testFuzzTransferFromERC20Chain(
        bool canFail,
        bool shouldReturnAnything,
        bool shouldThrow,
        bool result,
        address sender,
        address receiver,
        uint256 amount
    ) public {
        erc20_0.setShouldReturnAnything(shouldReturnAnything);
        erc20_0.setShouldThrow(shouldThrow);
        erc20_0.setResult(result);

        erc20_0.setShouldReturnAnything(shouldReturnAnything);
        erc20_0.setShouldThrow(shouldThrow);
        erc20_0.setResult(result);

        bool callSucceeds = !shouldThrow && (result || !shouldReturnAnything) || canFail;

        if (callSucceeds) {
            vm.expectCall(
                address(erc20_0), abi.encodeCall(ERC20Mock.transferFrom, (sender, receiver, amount))
            );

            vm.expectCall(
                address(erc20_1), abi.encodeCall(ERC20Mock.transferFrom, (sender, receiver, amount))
            );
        }

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_0), sender, receiver, amount
                ),
                BBCEncoder.encodeTransferFromERC20(
                    canFail, address(erc20_1), sender, receiver, amount
                )
            )
        );

        assertEq(success, callSucceeds);
    }

    // -- ERC721 -----------------------------------------------------------------------------------

    function testTransferFromERC721Single() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 tokenId = 0x02;

        vm.expectCall(
            address(erc721_0), abi.encodeCall(ERC721Mock.transferFrom, (sender, receiver, tokenId))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC721(
                canFail, address(erc721_0), sender, receiver, tokenId
            )
        );

        assertTrue(success);
    }

    function testTransferFromERC721SingleThrows() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 tokenId = 0x02;

        erc721_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC721(
                canFail, address(erc721_0), sender, receiver, tokenId
            )
        );

        assertFalse(success);
    }

    function testFuzzTransferFromERC721Single(
        bool canFail,
        bool shouldThrow,
        address sender,
        address receiver,
        uint256 tokenId
    ) public {
        erc721_0.setShouldThrow(shouldThrow);

        if (!shouldThrow || canFail) {
            vm.expectCall(
                address(erc721_0),
                abi.encodeCall(ERC721Mock.transferFrom, (sender, receiver, tokenId))
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC721(
                canFail, address(erc721_0), sender, receiver, tokenId
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    function testTransferFromERC721Chain() public {
        bool canFail = false;

        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 tokenId_0 = 0x02;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 tokenId_1 = 0x04;

        vm.expectCall(
            address(erc721_0),
            abi.encodeCall(ERC721Mock.transferFrom, (sender_0, receiver_0, tokenId_0))
        );

        vm.expectCall(
            address(erc721_1),
            abi.encodeCall(ERC721Mock.transferFrom, (sender_1, receiver_1, tokenId_1))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_0), sender_0, receiver_0, tokenId_0
                ),
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_1), sender_1, receiver_1, tokenId_1
                )
            )
        );

        assertTrue(success);
    }

    function testTransferFromERC721ChainFirstThrows() public {
        bool canFail = false;

        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 tokenId_0 = 0x02;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 tokenId_1 = 0x04;

        erc721_0.setShouldThrow(true);

        vm.expectCall(
            address(erc721_1),
            abi.encodeCall(ERC721Mock.transferFrom, (sender_1, receiver_1, tokenId_1)),
            0
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_0), sender_0, receiver_0, tokenId_0
                ),
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_1), sender_1, receiver_1, tokenId_1
                )
            )
        );

        assertFalse(success);
    }

    function testTransferFromERC721ChainSecondThrows() public {
        bool canFail = false;

        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 tokenId_0 = 0x02;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 tokenId_1 = 0x04;

        erc721_1.setShouldThrow(true);

        vm.expectCall(
            address(erc721_0),
            abi.encodeCall(ERC721Mock.transferFrom, (sender_0, receiver_0, tokenId_0))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_0), sender_0, receiver_0, tokenId_0
                ),
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_1), sender_1, receiver_1, tokenId_1
                )
            )
        );

        assertFalse(success);
    }

    function testFuzzTransferFromERC721Chain(
        bool canFail,
        bool shouldThrow,
        address sender,
        address receiver,
        uint256 tokenId
    ) public {
        erc721_0.setShouldThrow(shouldThrow);
        erc721_0.setShouldThrow(shouldThrow);

        if (!shouldThrow || canFail) {
            vm.expectCall(
                address(erc721_0),
                abi.encodeCall(ERC721Mock.transferFrom, (sender, receiver, tokenId))
            );

            vm.expectCall(
                address(erc721_1),
                abi.encodeCall(ERC721Mock.transferFrom, (sender, receiver, tokenId))
            );
        }

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_0), sender, receiver, tokenId
                ),
                BBCEncoder.encodeTransferFromERC721(
                    canFail, address(erc721_1), sender, receiver, tokenId
                )
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    // -- ERC6909 ----------------------------------------------------------------------------------

    function testTransferERC6909Single() public {
        bool canFail = false;
        address receiver = address(0xaabbccdd);
        uint256 tokenId = 0x45;
        uint256 amount = 0x46;

        vm.expectCall(
            address(erc6909_0), abi.encodeCall(ERC6909Mock.transfer, (receiver, tokenId, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC6909(canFail, address(erc6909_0), receiver, tokenId, amount)
        );

        assertTrue(success);
    }

    function testTransferERC6909SingleThrows() public {
        bool canFail = false;
        address receiver = address(0xaabbccdd);
        uint256 tokenId = 0x45;
        uint256 amount = 0x46;

        erc6909_0.setShouldThrow(true);

        vm.expectCall(
            address(erc6909_0), abi.encodeCall(ERC6909Mock.transfer, (receiver, tokenId, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC6909(canFail, address(erc6909_0), receiver, tokenId, amount)
        );

        assertFalse(success);
    }

    function testTransferERC6909SingleReturnsFalse() public {
        bool canFail = false;
        address receiver = address(0xaabbccdd);
        uint256 tokenId = 0x45;
        uint256 amount = 0x46;

        erc6909_0.setResult(false);

        vm.expectCall(
            address(erc6909_0), abi.encodeCall(ERC6909Mock.transfer, (receiver, tokenId, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC6909(canFail, address(erc6909_0), receiver, tokenId, amount)
        );

        assertFalse(success);
    }

    function testFuzzTransferERC6909Single(
        bool canFail,
        bool result,
        bool shouldThrow,
        address receiver,
        uint256 tokenId,
        uint256 amount
    ) public {
        erc6909_0.setResult(result);
        erc6909_0.setShouldThrow(shouldThrow);

        if (!shouldThrow && result || canFail) {
            vm.expectCall(
                address(erc6909_0),
                abi.encodeCall(ERC6909Mock.transfer, (receiver, tokenId, amount))
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferERC6909(canFail, address(erc6909_0), receiver, tokenId, amount)
        );

        assertEq(success, !shouldThrow && result || canFail);
    }

    function testTransferERC6909Chain() public {
        bool canFail = false;
        address receiver_0 = address(0xaabbccdd);
        uint256 tokenId_0 = 0x45;
        uint256 amount_0 = 0x46;

        address receiver_1 = address(0xeeffaabb);
        uint256 tokenId_1 = 0x47;
        uint256 amount_1 = 0x48;

        vm.expectCall(
            address(erc6909_0),
            abi.encodeCall(ERC6909Mock.transfer, (receiver_0, tokenId_0, amount_0))
        );

        vm.expectCall(
            address(erc6909_1),
            abi.encodeCall(ERC6909Mock.transfer, (receiver_1, tokenId_1, amount_1))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_0), receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_1), receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertTrue(success);
    }

    function testTransferERC6909ChainThrows() public {
        bool canFail = false;
        address receiver_0 = address(0xaabbccdd);
        uint256 tokenId_0 = 0x45;
        uint256 amount_0 = 0x46;

        address receiver_1 = address(0xeeffaabb);
        uint256 tokenId_1 = 0x47;
        uint256 amount_1 = 0x48;

        erc6909_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_0), receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_1), receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertFalse(success);
    }

    function testTransferERC6909ChainReturnsFalse() public {
        bool canFail = false;
        address receiver_0 = address(0xaabbccdd);
        uint256 tokenId_0 = 0x45;
        uint256 amount_0 = 0x46;

        address receiver_1 = address(0xeeffaabb);
        uint256 tokenId_1 = 0x47;
        uint256 amount_1 = 0x48;

        erc6909_0.setResult(false);

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_0), receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_1), receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertFalse(success);
    }

    function testFuzzTransferERC6909Chain(
        bool canFail,
        bool result,
        bool shouldThrow,
        address receiver_0,
        uint256 tokenId_0,
        uint256 amount_0,
        address receiver_1,
        uint256 tokenId_1,
        uint256 amount_1
    ) public {
        erc6909_0.setResult(result);
        erc6909_0.setShouldThrow(shouldThrow);
        erc6909_1.setResult(result);
        erc6909_1.setShouldThrow(shouldThrow);

        if (!shouldThrow && result || canFail) {
            vm.expectCall(
                address(erc6909_0),
                abi.encodeCall(ERC6909Mock.transfer, (receiver_0, tokenId_0, amount_0))
            );

            vm.expectCall(
                address(erc6909_1),
                abi.encodeCall(ERC6909Mock.transfer, (receiver_1, tokenId_1, amount_1))
            );
        }

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_0), receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferERC6909(
                    canFail, address(erc6909_1), receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertEq(success, !shouldThrow && result || canFail);
    }

    function testTransferFromERC6909Single() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 tokenId = 0x45;
        uint256 amount = 0x46;

        vm.expectCall(
            address(erc6909_0),
            abi.encodeCall(ERC6909Mock.transferFrom, (sender, receiver, tokenId, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC6909(
                canFail, address(erc6909_0), sender, receiver, tokenId, amount
            )
        );

        assertTrue(success);
    }

    function testTransferFromERC6909SingleThrows() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 tokenId = 0x45;
        uint256 amount = 0x46;

        erc6909_0.setShouldThrow(true);

        vm.expectCall(
            address(erc6909_0),
            abi.encodeCall(ERC6909Mock.transferFrom, (sender, receiver, tokenId, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC6909(
                canFail, address(erc6909_0), sender, receiver, tokenId, amount
            )
        );

        assertFalse(success);
    }

    function testTransferFromERC6909SingleReturnsFalse() public {
        bool canFail = false;
        address sender = address(0xaabbccdd);
        address receiver = address(0xeeffaabb);
        uint256 tokenId = 0x45;
        uint256 amount = 0x46;

        erc6909_0.setResult(false);

        vm.expectCall(
            address(erc6909_0),
            abi.encodeCall(ERC6909Mock.transferFrom, (sender, receiver, tokenId, amount))
        );

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC6909(
                canFail, address(erc6909_0), sender, receiver, tokenId, amount
            )
        );

        assertFalse(success);
    }

    function testFuzzTransferFromERC6909Single(
        bool canFail,
        bool result,
        bool shouldThrow,
        address sender,
        address receiver,
        uint256 tokenId,
        uint256 amount
    ) public {
        erc6909_0.setResult(result);
        erc6909_0.setShouldThrow(shouldThrow);

        if (!shouldThrow && result || canFail) {
            vm.expectCall(
                address(erc6909_0),
                abi.encodeCall(ERC6909Mock.transferFrom, (sender, receiver, tokenId, amount))
            );
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeTransferFromERC6909(
                canFail, address(erc6909_0), sender, receiver, tokenId, amount
            )
        );

        assertEq(success, !shouldThrow && result || canFail);
    }

    function testTransferFromERC6909Chain() public {
        bool canFail = false;
        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 tokenId_0 = 0x45;
        uint256 amount_0 = 0x46;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 tokenId_1 = 0x47;
        uint256 amount_1 = 0x48;

        vm.expectCall(
            address(erc6909_0),
            abi.encodeCall(ERC6909Mock.transferFrom, (sender_0, receiver_0, tokenId_0, amount_0))
        );

        vm.expectCall(
            address(erc6909_1),
            abi.encodeCall(ERC6909Mock.transferFrom, (sender_1, receiver_1, tokenId_1, amount_1))
        );

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_0), sender_0, receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_1), sender_1, receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertTrue(success);
    }

    function testTransferFromERC6909ChainThrows() public {
        bool canFail = false;
        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 tokenId_0 = 0x45;
        uint256 amount_0 = 0x46;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 tokenId_1 = 0x47;
        uint256 amount_1 = 0x48;

        erc6909_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_0), sender_0, receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_1), sender_1, receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertFalse(success);
    }

    function testTransferFromERC6909ChainReturnsFalse() public {
        bool canFail = false;
        address sender_0 = address(0xaabbccdd);
        address receiver_0 = address(0xeeffaabb);
        uint256 tokenId_0 = 0x45;
        uint256 amount_0 = 0x46;

        address sender_1 = address(0xccddeeff);
        address receiver_1 = address(0xaabbccdd);
        uint256 tokenId_1 = 0x47;
        uint256 amount_1 = 0x48;

        erc6909_0.setResult(false);

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_0), sender_0, receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_1), sender_1, receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertFalse(success);
    }

    function testFuzzTransferFromERC6909Chain(
        bool canFail,
        bool result,
        bool shouldThrow,
        address sender_0,
        address receiver_0,
        uint256 tokenId_0,
        uint256 amount_0,
        address sender_1,
        address receiver_1,
        uint256 tokenId_1,
        uint256 amount_1
    ) public {
        erc6909_0.setResult(result);
        erc6909_0.setShouldThrow(shouldThrow);
        erc6909_1.setResult(result);
        erc6909_1.setShouldThrow(shouldThrow);

        if (!shouldThrow && result || canFail) {
            vm.expectCall(
                address(erc6909_0),
                abi.encodeCall(
                    ERC6909Mock.transferFrom, (sender_0, receiver_0, tokenId_0, amount_0)
                )
            );

            vm.expectCall(
                address(erc6909_1),
                abi.encodeCall(
                    ERC6909Mock.transferFrom, (sender_1, receiver_1, tokenId_1, amount_1)
                )
            );
        }

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_0), sender_0, receiver_0, tokenId_0, amount_0
                ),
                BBCEncoder.encodeTransferFromERC6909(
                    canFail, address(erc6909_1), sender_1, receiver_1, tokenId_1, amount_1
                )
            )
        );

        assertEq(success, !shouldThrow && result || canFail);
    }

    // -- WETH -------------------------------------------------------------------------------------

    function testDepositWETHNothing() public {
        bool canFail = false;
        uint256 value = 0x00;

        vm.expectCall(address(weth), value, new bytes(0));

        bool success = lotus.takeAction(BBCEncoder.encodeDepositWETH(canFail,  value));

        assertTrue(success);
    }

    function testDepositWETHFromCaller() public {
        bool canFail = false;
        uint256 value = 0x01;

        vm.expectCall(address(weth), value, new bytes(0));

        bool success = lotus.takeActionWithValue(
            value, BBCEncoder.encodeDepositWETH(canFail, value)
        );

        assertTrue(success);
    }

    function testDepositWETHFromBalance() public {
        bool canFail = false;
        uint256 value = 0x01;

        vm.deal(address(lotus), value);

        vm.expectCall(address(weth), value, new bytes(0));

        bool success = lotus.takeAction(BBCEncoder.encodeDepositWETH(canFail, value));

        assertTrue(success);
    }

    function testDepositWETHThrows() public {
        bool canFail = false;
        uint256 value = 0x00;

        weth.setShouldThrow(true);

        bool success = lotus.takeAction(BBCEncoder.encodeDepositWETH(canFail, value));

        assertFalse(success);
    }

    function testFuzzDepositWETH(
        bool canFail,
        bool shouldThrow,
        bool fromCaller,
        uint256 value
    ) public {
        address alice = address(0xaaaaaaaa);
        vm.startPrank(alice);

        weth.setShouldThrow(shouldThrow);

        if (canFail || !shouldThrow) {
            vm.expectCall(address(weth), value, new bytes(0));
        }

        bool success;

        if (fromCaller) {
            vm.deal(alice, value);

            success = lotus.takeActionWithValue(
                value, BBCEncoder.encodeDepositWETH(canFail, value)
            );
        } else {
            vm.deal(address(lotus), value);

            success = lotus.takeAction(BBCEncoder.encodeDepositWETH(canFail, value));
        }

        assertEq(success, canFail || !shouldThrow);

        vm.stopPrank();
    }

    function testWithdrawWETH() public {
        bool canFail = false;
        uint256 value = 0x01;

        vm.expectCall(address(weth), abi.encodeCall(WETHMock.withdraw, (value)));

        bool success =
            lotus.takeAction(BBCEncoder.encodeWithdrawWETH(canFail, value));

        assertTrue(success);
    }

    function testWithdrawWETHTHrows() public {
        bool canFail = false;
        uint256 value = 0x01;

        weth.setShouldThrow(true);

        bool success =
            lotus.takeAction(BBCEncoder.encodeWithdrawWETH(canFail, value));

        assertFalse(success);
    }

    function testFuzzWithdrawWETH(bool canFail, bool shouldThrow, uint256 value) public {
        weth.setShouldThrow(shouldThrow);

        if (canFail || !shouldThrow) {
            vm.expectCall(address(weth), new bytes(0));
        }

        bool success =
            lotus.takeAction(BBCEncoder.encodeWithdrawWETH(canFail, value));

        assertEq(success, canFail || !shouldThrow);
    }

    function testWETHSendIsCheaperThanDeposit() public {
        address alice = address(0xaaaaaa);
        address cannonWeth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        uint256 value = 0x02;
        uint256 gasDepositBefore;
        uint256 gasDepositAfter;
        uint256 gasSendBefore;
        uint256 gasSendAfter;

        vm.etch(cannonWeth, wethBytecode());
        vm.deal(alice, value * 5);
        vm.startPrank(alice);

        // call weth once to make sure the slot is warm
        assembly {
            pop(call(gas(), cannonWeth, value, 0x00, 0x00, 0x00, 0x00))
        }

        // call deposit then send
        assembly {
            // call weth.deposit()
            mstore(0x00, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
            gasDepositBefore := gas()
            pop(call(gas(), cannonWeth, value, 0x00, 0x04, 0x00, 0x00))
            gasDepositAfter := gas()

            // send ether to weth (no calldata)
            gasSendBefore := gas()
            pop(call(gas(), cannonWeth, value, 0x00, 0x00, 0x00, 0x00))
            gasSendAfter := gas()
        }

        assertLt(gasSendBefore - gasSendAfter, gasDepositBefore - gasDepositAfter);

        // call send then deposit
        assembly {
            // send ether to weth (no calldata)
            gasSendBefore := gas()
            pop(call(gas(), cannonWeth, value, 0x00, 0x00, 0x00, 0x00))
            gasSendAfter := gas()

            // call weth.deposit()
            mstore(0x00, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
            gasDepositBefore := gas()
            pop(call(gas(), cannonWeth, value, 0x00, 0x04, 0x00, 0x00))
            gasDepositAfter := gas()
        }

        assertLt(gasSendBefore - gasSendAfter, gasDepositBefore - gasDepositAfter);

        vm.stopPrank();
    }

    // -- DYNAMIC ----------------------------------------------------------------------------------

    function testDynCallSingle() public {
        bool canFail = false;
        uint256 value = 0x45;
        bytes memory data = hex"deadbeef";

        vm.deal(address(lotus), value);

        vm.expectCall(address(dynTarget_0), value, data);

        bool success = lotus.takeAction(
            BBCEncoder.encodeDynCall(
                canFail,
                address(dynTarget_0),
                value,
                data
            )
        );

        assertTrue(success);
    }

    function testDynCallSingleThrows() public {
        bool canFail = false;
        uint256 value = 0x45;
        bytes memory data = hex"deadbeef";

        vm.deal(address(lotus), value);

        dynTarget_0.setShouldThrow(true);

        bool success = lotus.takeAction(
            BBCEncoder.encodeDynCall(
                canFail,
                address(dynTarget_0),
                value,
                data
            )
        );

        assertFalse(success);
    }

    function testDynCallSingleOutOfFunds() public {
        bool canFail = false;
        uint256 value = 0x45;
        bytes memory data = hex"deadbeef";

        bool success = lotus.takeAction(
            BBCEncoder.encodeDynCall(
                canFail,
                address(dynTarget_0),
                value,
                data
            )
        );

        assertFalse(success);
    }

    function testFuzzDynCallSingle(
        bool shouldThrow,
        bool canFail,
        uint256 value,
        bytes calldata data
    ) public {
        bytes4 dataSelector;

        assembly {
            dataSelector := shr(0xe0, calldataload(data.offset))
        }

        vm.assume(dataSelector != DynTargetMock.setShouldThrow.selector);

        dynTarget_0.setShouldThrow(shouldThrow);

        vm.deal(address(lotus), value);

        if (!shouldThrow || canFail) {
            vm.expectCall(address(dynTarget_0), value, data);
        }

        bool success = lotus.takeAction(
            BBCEncoder.encodeDynCall(
                canFail,
                address(dynTarget_0),
                value,
                data
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    function testDynCallChain() public {
        bool canFail = false;
        uint256 value_0 = 0x45;
        bytes memory data_0 = hex"deadbeef";
        uint256 value_1 = 0x46;
        bytes memory data_1 = hex"beefdead";

        vm.deal(address(lotus), value_0 + value_1);

        vm.expectCall(address(dynTarget_0), value_0, data_0);
        vm.expectCall(address(dynTarget_1), value_1, data_1);

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_0),
                    value_0,
                    data_0
                ),
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_1),
                    value_1,
                    data_1
                )
            )
        );

        assertTrue(success);
    }

    function testDynCallChainThrows() public {
        bool canFail = false;
        uint256 value_0 = 0x45;
        bytes memory data_0 = hex"deadbeef";
        uint256 value_1 = 0x46;
        bytes memory data_1 = hex"beefdead";

        dynTarget_0.setShouldThrow(true);

        vm.deal(address(lotus), value_0 + value_1);

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_0),
                    value_0,
                    data_0
                ),
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_1),
                    value_1,
                    data_1
                )
            )
        );

        assertFalse(success);
    }

    function testDynCallChainOutOfFunds() public {
        bool canFail = false;
        uint256 value_0 = 0x45;
        bytes memory data_0 = hex"deadbeef";
        uint256 value_1 = 0x46;
        bytes memory data_1 = hex"beefdead";

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_0),
                    value_0,
                    data_0
                ),
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_1),
                    value_1,
                    data_1
                )
            )
        );

        assertFalse(success);
    }

    function testFuzzDynCallChain(
        bool shouldThrow,
        bool canFail,
        uint256 value_0,
        bytes calldata data_0,
        uint256 value_1,
        bytes calldata data_1
    ) public {
        value_1 = bound(value_1, 0, type(uint256).max - value_0);

        bytes4 dataSelector_0;
        bytes4 dataSelector_1;

        assembly {
            dataSelector_0 := shr(0xe0, calldataload(data_0.offset))
            dataSelector_1 := shr(0xe0, calldataload(data_1.offset))
        }

        vm.assume(dataSelector_0 != DynTargetMock.setShouldThrow.selector);
        vm.assume(dataSelector_1 != DynTargetMock.setShouldThrow.selector);

        dynTarget_0.setShouldThrow(shouldThrow);

        vm.deal(address(lotus), value_0 + value_1);

        if (!shouldThrow || canFail) {
            vm.expectCall(address(dynTarget_0), value_0, data_0);
            vm.expectCall(address(dynTarget_1), value_1, data_1);
        }

        bool success = lotus.takeAction(
            abi.encodePacked(
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_0),
                    value_0,
                    data_0
                ),
                BBCEncoder.encodeDynCall(
                    canFail,
                    address(dynTarget_1),
                    value_1,
                    data_1
                )
            )
        );

        assertEq(success, !shouldThrow || canFail);
    }

    // -- UTILITIES --------------------------------------------------------------------------------
    function assumeReasonableInt256(
        int256 value
    ) internal pure {
        // why? bc `-value` in this exact case overflows :(
        vm.assume(
            value != -57896044618658097711785492504343953926634992332820282019728792003956564819968
        );
    }

    function testRoute1() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22739116
        // v3->v2
        bytes memory data = hex"03001416b70f44719b227278a2dc1122e8106cc929ecd11460a39010e4892b862d1bb6bdde908215ac5af6f3010713ff5f798bcc70000000006d02001460a39010e4892b862d1bb6bdde908215ac5af6f3071475e59c3dbfef00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc21416b70f44719b227278a2dc1122e8106cc929ecd10713ff5f798bcc70";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute2() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22744461
        // v2->v3
        bytes memory data = hex"020014caa004418eb42cdf00cb057b7c9e28f0ffd840a50906d2418020d00186a100145615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000a6030014b09c5dad762df413d5fc677f03400d3a3b9993a1145615deb798bb3e4dfa0139dfa1b3d433cc23b72f010906d2418020d00186a100000000360600142a3bff78b79a009976eea096a51a948a3dc00e3414b09c5dad762df413d5fc677f03400d3a3b9993a10906d2418020d00186a1060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214caa004418eb42cdf00cb057b7c9e28f0ffd840a5071b27c3b9de2027";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute3() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22744461
        // v3->v2
        bytes memory data = hex"030014084b5191bd08412952337b1108b6e5942418928f1459e7bee6374a3f6ecb33180ece978fd4f2b7cea200071858e394356a36000000006d02001459e7bee6374a3f6ecb33180ece978fd4f2b7cea20007188fb3de483307145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214084b5191bd08412952337b1108b6e5942418928f071858e394356a36";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute4() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22744461
        bytes memory data = hex"030014e092769bc1fa5262d4f48353f90890dcc339bf80145615deb798bb3e4dfa0139dfa1b3d433cc23b72f000701481ab355893800000000bd04001439d5313c3750140e5042887413ba8aa6145a9bd214c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20027100000c814ce90a69d3daee08fc86662acd93f20d161c940440107fe665a5fed3d69000000003406001439d5313c3750140e5042887413ba8aa6145a9bd214c8eaf20ce476be72be3548f3e57e8fa129c0a105073071e1213bbe46060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214e092769bc1fa5262d4f48353f90890dcc339bf800701481ab3558938";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }


    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        console.log("here");

        console.logBytes(rawData);


        //swap
        // _swap _settle_all _take

        // 0. swap
        // _settle 逻辑
        // 1. 先sync
        // 2. transfer
        // 3. settle



        // swap
        (bool x, bytes memory returnData )= address(0x000000000004444c5dc75cB358380D2e3dE08A90).call(rawData);

        (int256 delta) = abi.decode(returnData, (int256));
        console.log( BalanceDelta.wrap(delta).amount0());
        console.log( BalanceDelta.wrap(delta).amount1());

        // //settle 支付需要的token
        // bytes memory takePayload = abi.encodeWithSelector(0x0b0d9c09,
        // 0x39D5313C3750140E5042887413bA8AA6145a9bd2, address(this),
        // uint256(int256(    BalanceDelta.wrap(delta).amount0()))
        // );
        // address(0x000000000004444c5dc75cB358380D2e3dE08A90).call(takePayload);
        
        // bytes memory syncPayload = abi.encodeWithSelector(0xa5841194, 0x39D5313C3750140E5042887413bA8AA6145a9bd2);
        // address(0x000000000004444c5dc75cB358380D2e3dE08A90).call(syncPayload);

        // 1. sync 
        bytes memory syncPayload = abi.encodeWithSelector(0xa5841194, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address(0x000000000004444c5dc75cB358380D2e3dE08A90).call(syncPayload);

        // 2. transfer
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).transfer(0x000000000004444c5dc75cB358380D2e3dE08A90, 
            uint256( -int256(BalanceDelta.wrap(delta).amount1()))
        );


        // 3. settle
        // settle 是指用 sender 结算， 也可用 settleFor 结算支付
        bytes memory settlePayload = abi.encodeWithSelector(0x11da60b4);
        address(0x000000000004444c5dc75cB358380D2e3dE08A90).call(settlePayload);


        // 4. take
        bytes memory takePayload = abi.encodeWithSelector( 0x0b0d9c09,  0x44ff8620b8cA30902395A7bD3F2407e1A091BF73, 
        address(this), uint256(uint128(BalanceDelta.wrap(delta).amount0())));
        address(0x000000000004444c5dc75cB358380D2e3dE08A90).call(takePayload);

    }



    function testUniV4Swap() public {
        uint256 amount = 1000 ether;
        vm.deal(address(this), 1000 ether);


        IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        weth.deposit{value: amount}();
        weth.approve(0x000000000004444c5dc75cB358380D2e3dE08A90, 100 ether);

        bytes memory empty = new bytes(0);

        bytes memory swapPayload = abi.encodeWithSelector(0xf3cd914c,
         0x44ff8620b8cA30902395A7bD3F2407e1A091BF73,
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        10000,200,0,
        false,
        0x113, //17969443
        // 4295128739+1,
        1461446703485210103287273052203988822378723970342-1,
        empty);


        bytes memory payload = abi.encodeWithSelector(0x48c89491, swapPayload);

        address(0x000000000004444c5dc75cB358380D2e3dE08A90).call(payload);

    }

    function testRoute5() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22747184
        // v3->v3
        bytes memory data = hex"030014e0554a476a092703abdb3ef35c80e0d76d32939f145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00080d0a96cd9f634c93000000009e03001488e6a0c2ddd26feeb64f039a2c41296fcb3f5640145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0105008743490c0000000031060014a0b86991c6218b36c1d19d4a2e9eb0ce3606eb481488e6a0c2ddd26feeb64f039a2c41296fcb3f5640048743490c060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214e0554a476a092703abdb3ef35c80e0d76d32939f080d0a96cd9f634c93";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute6() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22747184
        // v2->v3
        bytes memory data = hex"020014b011eeaab8bf0c6de75510128da95498e4b7e67f0905598949efebf14d8c00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000a6030014ac4b3dacb91461209ae9d41ec517c2b9cb1b7daf145615deb798bb3e4dfa0139dfa1b3d433cc23b72f010905598949efebf14d8c00000000360600144d224452801aced8b2f0aebe155379bb5d59438114ac4b3dacb91461209ae9d41ec517c2b9cb1b7daf0905598949efebf14d8c060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214b011eeaab8bf0c6de75510128da95498e4b7e67f07579fe833fc6420";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute7() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22760684
        // v3->v3
        bytes memory data = hex"0300144585fe77225b41b697c938b018e2ac67ac5a20c0145615deb798bb3e4dfa0139dfa1b3d433cc23b72f000800b55f274eb1ffe4000000009a030014e6ff8b9a37b0fab776134636d9981aa778c4e718145615deb798bb3e4dfa0139dfa1b3d433cc23b72f010301b93900000000300600142260fac5e5542a773aa44fbcfedf7c193bc2c59914e6ff8b9a37b0fab776134636d9981aa778c4e7180301b939060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2144585fe77225b41b697c938b018e2ac67ac5a20c007b55f274eb1ffe4";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute8() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22760684
        // v2->v4
        bytes memory data = hex"03001407aa6584385cca15c2c6e13a5599ffc2d177e33b1427fa67302c513f5512bbfa5065800c2d7b3871f4000710d02739ba00c2000000006d02001427fa67302c513f5512bbfa5065800c2d7b3871f4000711a2f7f836fe0b145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc21407aa6584385cca15c2c6e13a5599ffc2d177e33b0710d02739ba00c2";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute9() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22760684
        // v2->v4
        bytes memory data = hex"03001498409d8ca9629fbe01ab1b914ebf304175e384c81460031819a16266d896268cfea5d5be0b6c2b5d75010712605a1c8c0c50000000008d02001460031819a16266d896268cfea5d5be0b6c2b5d7507127efd492fb30700145615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000200000000000000000000000000000000000000000000000000000000000000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc21498409d8ca9629fbe01ab1b914ebf304175e384c80712605a1c8c0c50";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }


    function testRoute10() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //success @22821145
        // v2->v2->v2
        bytes memory data = hex"02001492ad5f399a278754637d84e9cba7cf405c901b9500091df65e087161d22100145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0000010b0300144910c39f3eff8c54cf88d2ca384fe30609cb4d39145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00091df65e087161d221000000000036060014d5930c307d7395ff807f2921f12c5eb82131a789144910c39f3eff8c54cf88d2ca384fe30609cb4d39091df65e087161d22100030014a276d842091a84ff99352e3f454760e9f7a617eb145615deb798bb3e4dfa0139dfa1b3d433cc23b72f010303a2c50000000030060014a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4814a276d842091a84ff99352e3f454760e9f7a617eb0303a2c5060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc21492ad5f399a278754637d84e9cba7cf405c901b95065af3107a4000";

        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);

        address(lotus).call(payload);

        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute11() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //v3->v3->v2
        //@22822327
        bytes memory data = hex"0300141d702a07379b1a585eff05cd5c8a2e64494672db145615deb798bb3e4dfa0139dfa1b3d433cc23b72f01070a7cd495b8b0d100000000dd03001496c12209c1130fc16c432978c45f7f6b424ef18d140d4a11d5eeaac28ec3f61d100daf4d40471f185200084f01930ef6e4e7f80000000035060014f34ca6b7fe3d6b1c8635a6bf2bd7bdd252f164261496c12209c1130fc16c432978c45f7f6b424ef18d084f01930ef6e4e7f80200140d4a11d5eeaac28ec3f61d100daf4d40471f1852070a8ab5e404d61c00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2141d702a07379b1a585eff05cd5c8a2e64494672db070a7cd495b8b0d1";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute12() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //v3->v2->v2
        //@22822337
        bytes memory data = hex"030014bfba6254831605a6bfa1d6df1e4b85a22c5061a9145ad7452ceafdaeb0936507d5bb5890964ef56bd3000712605a1c8c0c5000000000a20200145ad7452ceafdaeb0936507d5bb5890964ef56bd30003c3d48214b4e16d0168e52d35cacd2c6185b44281ec28c9dc00000000020014b4e16d0168e52d35cacd2c6185b44281ec28c9dc00071278d6e2500a08145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214bfba6254831605a6bfa1d6df1e4b85a22c5061a90712605a1c8c0c50";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute13() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        //v3->v2->v2
        //@22822337
        bytes memory data = hex"030014a3f558aebaecaf0e11ca4b2199cc5ed341edfd74145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0008ee919b7f005f32e900000001070600145a98fcbea516cf06857215779fd812ca3bef1b32146edca62d3c6210e2a03509907ce1f3671d3e767908116e6480ffa0cd170200146edca62d3c6210e2a03509907ce1f3671d3e767900030e74c9145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014dac17f958d2ee523a2206206994597c13d831ec71417c1ae82d99379240059940093762c5e4539aba5030e74c902001417c1ae82d99379240059940093762c5e4539aba507015633237f8f8f00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214a3f558aebaecaf0e11ca4b2199cc5ed341edfd740701481ab3558938";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute14() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        // 222 ok
        //@22851387
        bytes memory data = hex"020014fb4492a1cd2a28d08b0b2a3ffa567342ea93776f040f0c3ce700145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000103060014a3d4bee77b05d4a0c943877558ce21a763c4fa29143aa6ba6035caea853e0e4ec8d271c9ebf1246e26040f0c3ce70200143aa6ba6035caea853e0e4ec8d271c9ebf1246e26030e58ae00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4814b4e16d0168e52d35cacd2c6185b44281ec28c9dc030e58ae020014b4e16d0168e52d35cacd2c6185b44281ec28c9dc00070151fbf71d90d0145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214fb4492a1cd2a28d08b0b2a3ffa567342ea93776f0701481ab3558938";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute15() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        // 233  ok
        //@22851692
        bytes memory data = hex"020014d3d2e2692501a5c9ca623199d38826e513033a17077f965989afc4cd00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000107030014d0fc8ba7e267f2bc56044a7715a489d851dc6d78145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0103fc2cf000000000340600141f9840a85d5af5bf1d1762f925bdaddc4201f98414d0fc8ba7e267f2bc56044a7715a489d851dc6d78077f965989afc4cd030014a276d842091a84ff99352e3f454760e9f7a617eb145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0107fed8f93628856e0000000030060014a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4814a276d842091a84ff99352e3f454760e9f7a617eb0303d310060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214d3d2e2692501a5c9ca623199d38826e513033a17065af3107a4000";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute16() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        // 223 ok
        //@22851692
        bytes memory data = hex"020014d3d2e2692501a5c9ca623199d38826e513033a17077f965989afc4cd00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f000001060600141f9840a85d5af5bf1d1762f925bdaddc4201f98414ebfb684dd2b01e698ca6c14f10e4f289934a54d6077f965989afc4cd020014ebfb684dd2b01e698ca6c14f10e4f289934a54d6000303cab4145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000030014a276d842091a84ff99352e3f454760e9f7a617eb145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0107fed8f93628856e0000000030060014a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4814a276d842091a84ff99352e3f454760e9f7a617eb0303cab4060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214d3d2e2692501a5c9ca623199d38826e513033a17065af3107a4000";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }


    function testRoute17() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        // 322 ok
        //@22851692
        bytes memory data = hex"0300146fb092521191ab1ec60c83ae9e71dfafb25da9d6145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0109e40906d17955b8c3e40000000108060014e636f94a71ec52cc61ef21787ae351ad832347b714e5009b028aa21aec7b9086f839e428aa77b71c54091bf6f92e86aa473c1c020014e5009b028aa21aec7b9086f839e428aa77b71c540337253c00145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014dac17f958d2ee523a2206206994597c13d831ec7140d4a11d5eeaac28ec3f61d100daf4d40471f18520337253c0200140d4a11d5eeaac28ec3f61d100daf4d40471f1852070516771b2b96c800145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2146fb092521191ab1ec60c83ae9e71dfafb25da9d607050b8bb8f062aa";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

    function testRoute18() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        // 332 ok
        //@22851692
        bytes memory data = hex"0300148d4e39d4380392994f50e2c8413ddffe7e720a7b145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0009e783a189fa14a4141400000001090300148119d42124a5a55ef755dcc973bf3c7069f8181d145615deb798bb3e4dfa0139dfa1b3d433cc23b72f0103f1b1c20000000036060014b56aaac80c931161548a49181c9e000a19489c44148119d42124a5a55ef755dcc973bf3c7069f8181d09187c5e7605eb5bebec060014dac17f958d2ee523a2206206994597c13d831ec7140d4a11d5eeaac28ec3f61d100daf4d40471f1852030e4e3e0200140d4a11d5eeaac28ec3f61d100daf4d40471f1852070151bd3052a1b600145615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2148d4e39d4380392994f50e2c8413ddffe7e720a7b0701481ab3558938";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }

        function testRoute19() public {
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        // 332 ok
        //@22873544
        bytes memory data = hex"020014a27e5775317f3f301b5b08babcde0a20feae7f09000902f0ffba2b89cc56e814fce863461c1e27ca10a19939b8426bb8f4d61de200000108060014eeeeeb57642040be42185f49c52f7e9b38f8eeee141cedaddcd6ab52e78902b734a9cf0137856de70e0902f0ffba2b89cc56e80200141cedaddcd6ab52e78902b734a9cf0137856de70e031b72ab0014fce863461c1e27ca10a19939b8426bb8f4d61de200000000060014a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4814b4e16d0168e52d35cacd2c6185b44281ec28c9dc031b72ab020014b4e16d0168e52d35cacd2c6185b44281ec28c9dc0007027f8791ec4ca114fce863461c1e27ca10a19939b8426bb8f4d61de200000000060014c02aaa39b223fe8d0a0e5c4f27ead9083c756cc214a27e5775317f3f301b5b08babcde0a20feae7f090702708c3ee7a4bd";
        bytes memory payload = abi.encodePacked(uint32(0x19ff8034), data);
        address(lotus).call(payload);
        console.log(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
    }


}