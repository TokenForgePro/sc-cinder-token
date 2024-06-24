// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UNISWAP_V2_ROUTER02, SUSHISWAP_V2_ROUTER02, PANCAKESWAP_V2_ROUTER02, FRAXSWAP_V2_ROUTER02} from "test/utils/constant_eth.sol";

import {Cindr} from "src/Cindr.sol";

contract CindrTokenFeesTest is Test {
    Cindr CindrToken;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address owner;
    address marketingWallet;
    address user1;
    address user2;

    uint16 _taxFee = 15; // 1.5%
    uint16 _burnFee = 15; //  1.5%
    uint16 _liquidityFee = 10; // 1%
    uint16 _marketingFee = 10; // 1%

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        owner = makeAddr("owner");
        marketingWallet = makeAddr("marketingWallet");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy the Cindr token contract on the forked mainnet
        CindrToken = new Cindr(
            "Cindr",
            "CND",
            1_000_000_000,
            UNISWAP_V2_ROUTER02,
            marketingWallet
        );

        uniswapV2Router = IUniswapV2Router02(UNISWAP_V2_ROUTER02);
        uniswapV2Pair = CindrToken.uniswapV2Pair();

        CindrToken.approve(UNISWAP_V2_ROUTER02, type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: 10 ether}(
            address(CindrToken),
            1_000_000_000 / 4,
            0,
            0,
            owner,
            block.timestamp
        );

        // Transfer some tokens to user1 for testing
        CindrToken.transfer(user1, 7_200_000 * 10 ** 9);
    }

    function testIsExcludedFromReward() public {
        bool isExcluded = CindrToken.isExcludedFromReward(address(this));
        assertEq(
            isExcluded,
            false,
            "Address should not be excluded from reward by default"
        );
    }

    function test_IsExcludedFromFee() public {
        bool isExcluded = CindrToken.isExcludedFromFee(uniswapV2Pair);
        assertTrue(isExcluded, "uniswapV2Pair should be excluded from fee");

        isExcluded = CindrToken.isExcludedFromFee(address(CindrToken));
        assertTrue(
            isExcluded,
            "CindrToken contract should be excluded from fee"
        );

        isExcluded = CindrToken.isExcludedFromFee(user1);
        assertFalse(isExcluded, "user1 should not be excluded from fee");
    }
    function test_FeeDistribution() public {
        uint256 initialBalance = CindrToken.balanceOf(user1);

        // Transfer tokens from user1 to user2 and check fee distribution
        uint256 transferAmount = 1000 * 10 ** 9;
        vm.prank(user1);
        CindrToken.transfer(user2, transferAmount);

        uint256 user1Balance = CindrToken.balanceOf(user1);
        uint256 user2Balance = CindrToken.balanceOf(user2);
        uint256 marketingWalletBalance = CindrToken.balanceOf(marketingWallet);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertApproxEqAbs(user1Balance, initialBalance - transferAmount, 200);

        assertGt(
            user2Balance,
            950 * 10 ** 9,
            "User2 balance should receive transfer amount minus fees"
        );

        assertGe(
            marketingWalletBalance,
            10 * 10 ** 9,
            "Marketing wallet should receive the marketing fee"
        );
    }
}
