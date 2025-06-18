// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console} from "lib/forge-std/src/Test.sol";


import {LotusRouterEncoder} from "../src/LotusRouterEncoder.sol";
import { Action } from "src/types/Action.sol";

contract LotusRouterTest is Test {

    function setUp() public {
        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/LF6UWFTfNBA4ixtff5yYnK_HRmiKC1-Y"
            // "http://127.0.0.1:8545",
        );

    }

    function testEncodeCycle1() public {
    // @22717947  输入金额: 360754491787576 输出金额: 1670810146967540 预期利润: 0.001310055655179964 ETH

    // currecy0 =  '0x24bd7C84Da35fcEEFB9cf63B2CC02eb289e8A69a'
    // currecy1 = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
    // direction = // 16
    // fee = // 30
    // poolAddress = // '0xdE719ea67D9d52Ba0b2038C96279F8D87Da884d8'
    // poolType = // 2000


    // amountIn = 0n
    // currecy0 = '0x24bd7C84Da35fcEEFB9cf63B2CC02eb289e8A69a'
    // currecy1 = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
    // direction = 1
    // fee = 3000
    // hooks = '0x0000000000000000000000000000000000000000'
    // poolAddress = '0x6431BE30788d8BBE24D992d871D3E618DeA17233'
    // poolType = 3000
    // tickSpacing = 0

        Action[] memory actions = new Action[](3);
        actions[0] = Action.TransferERC20;
        actions[1] = Action.SwapUniV2;
        actions[2] = Action.SwapUniV3;

        bytes32[] memory data = new bytes32[](18);
        uint256 dataIndex = 0;

        // transfer weth
        data[dataIndex++] = bytes32(uint256(0)); // canFail
        data[dataIndex++] = bytes32(uint256(uint160(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)))); 
        data[dataIndex++] = bytes32(uint256(uint160(address(0xdE719ea67D9d52Ba0b2038C96279F8D87Da884d8)))); 
        data[dataIndex++] = bytes32(uint256(360754491787576)); 

        // SwapUniV1 数据
        // data[dataIndex++] = bytes32(uint256(1)); // canFail
        // data[dataIndex++] = bytes32(uint256(uint160(address(0x1234)))); // pair
        // data[dataIndex++] = bytes32(uint256(1000)); // amountIn
        // data[dataIndex++] = bytes32(uint256(900)); // amountOut
        // data[dataIndex++] = bytes32(uint256(uint160(address(0x5678)))); // to

        // SwapUniV2 数据
        data[dataIndex++] = bytes32(uint256(0)); // canFail
        data[dataIndex++] = bytes32(uint256(uint160(address(0xdE719ea67D9d52Ba0b2038C96279F8D87Da884d8)))); // pair
        data[dataIndex++] = bytes32(uint256(0)); // amount0Out
        data[dataIndex++] = bytes32(uint256(0)); // amount1Out
        data[dataIndex++] = bytes32(uint256(uint160(address(0x6431BE30788d8BBE24D992d871D3E618DeA17233)))); // to

        // SwapUniV3 数据
        data[dataIndex++] = bytes32(uint256(0)); // canFail
        data[dataIndex++] = bytes32(uint256(uint160(address(0x6431BE30788d8BBE24D992d871D3E618DeA17233)))); // pool
        data[dataIndex++] = bytes32(uint256(uint160(address(0x1234123412341234123412341234123412341234)))); // recipient
        data[dataIndex++] = bytes32(uint256(1)); // zeroForOne
        data[dataIndex++] = bytes32(uint256(int256(-1670810146967540))); // amountSpecified
        data[dataIndex++] = bytes32(uint256(123456)); // sqrtPriceLimitX96

        new LotusRouterEncoder(actions, data);
    }

}