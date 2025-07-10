// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console} from "lib/forge-std/src/Test.sol";


import {BBCEncoder} from "../src/util/BBCEncoder.sol";
import {BBCDecoder} from "../src/util/BBCDecoder.sol";
import {PoolKey, SwapParams, Currency, IHooks} from "../src/types/protocols/UniV4Pool.sol";
import {LotusRouterEncoder} from "../src/LotusRouterEncoder.sol";
import { Action } from "src/types/Action.sol";

contract LotusRouterTest is Test {

    function setUp() public {
        // vm.createSelectFork(
        //     // "https://eth-mainnet.g.alchemy.com/v2/LF6UWFTfNBA4ixtff5yYnK_HRmiKC1-Y"
        //     // "http://127.0.0.1:8545",
        // );

    }

    function testEncodeCycle1() public {

        


    }

}