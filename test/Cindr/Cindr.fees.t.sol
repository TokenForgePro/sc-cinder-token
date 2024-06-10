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
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
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

    function test_SetTaxFee() public {
        CindrToken.setTaxFeePercent(20);
        uint16 taxFee = CindrToken.taxFee();

        assertEq(taxFee, 20, "Tax fee should be set to 2%");
    }

    function test_SetBurnFee() public {
        CindrToken.setBurnFeePercent(20);
        uint16 burnFee = CindrToken.burnFee();

        assertEq(burnFee, 20, "Burn fee should be set to 2%");
    }

    function test_SetLiquidityFee() public {
        CindrToken.setLiquidityFeePercent(20);
        uint16 liquidityFee = CindrToken.liquidityFee();

        assertEq(liquidityFee, 20, "Liquidity fee should be set to 2%");
    }

    function test_SetMarketingFee() public {
        CindrToken.setMarketingFeePercent(20);
        uint16 marketingFee = CindrToken.marketingFee();

        assertEq(marketingFee, 20, "Marketing fee should be set to 2%");
    }

    function testSetMaxTxPercent() public {
        uint256 newMaxTxPercent = 5; // 5%

        CindrToken.setMaxTxPercent(newMaxTxPercent);

        uint256 expectedMaxTxAmount = (CindrToken.totalSupply() *
            newMaxTxPercent) / 100;
        assertEq(
            CindrToken._maxTxAmount(),
            expectedMaxTxAmount,
            "Max transaction amount should be set correctly"
        );
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

    function test_ExcludeFromFee() public {
        CindrToken.excludeFromFee(user1);
        bool isExcluded = CindrToken.isExcludedFromFee(user1);

        assertTrue(isExcluded, "User1 should be excluded from fee");

        // Transfer tokens from excluded user1 to user2
        uint256 initialBalance = CindrToken.balanceOf(user1);
        uint256 transferAmount = 1_000 * 10 ** 9;

        vm.prank(user1);
        CindrToken.transfer(user2, transferAmount);

        uint256 user1Balance = CindrToken.balanceOf(user1);
        uint256 user2Balance = CindrToken.balanceOf(user2);

        assertApproxEqAbs(user1Balance, initialBalance - transferAmount, 200);

        assertLt(
            user2Balance,
            transferAmount,
            "User2 balance should not receive full transfer amount recipient is not excluded from fee"
        );
    }

    function test_IncludeInFee() public {
        CindrToken.includeInFee(user1);
        bool isExcluded = CindrToken.isExcludedFromFee(user1);
        assertFalse(isExcluded, "User1 should be included in fee");

        // Transfer tokens from included user1 to user2
        uint256 initialBalance = CindrToken.balanceOf(user1);
        uint256 transferAmount = 1_000 * 10 ** 9;

        vm.prank(user1);
        CindrToken.transfer(user2, transferAmount);

        uint256 user1Balance = CindrToken.balanceOf(user1);
        uint256 user2Balance = CindrToken.balanceOf(user2);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        // console.log("user1Balance %d to %d", currentOwner, newOwner);

        assertApproxEqAbs(user1Balance, initialBalance - transferAmount, 200);

        assertEq(
            user2Balance,
            975 * 10 ** 9, // 950
            "User2 balance should receive transfer amount minus fees"
        );
    }

    function test_RemoveAllFee() public {
        CindrToken.excludeFromReward(user1);
        CindrToken.excludeFromReward(owner);

        // Set initial fees to non-zero values
        // vm.startPrank(owner);
        CindrToken.setTaxFeePercent(15);
        CindrToken.setBurnFeePercent(15);
        CindrToken.setLiquidityFeePercent(10);
        CindrToken.setMarketingFeePercent(10);
        // vm.stopPrank();

        vm.warp(block.timestamp + 150);

        // Perform a transfer to initialize fees
        vm.prank(user1);
        CindrToken.transfer(owner, 10_000 * 10 ** 9);

        // Debug: Check balances after the first transfer
        console.log(
            "Owner balance after first transfer:",
            CindrToken.balanceOf(owner)
        );
        console.log(
            "User1 balance after first transfer:",
            CindrToken.balanceOf(user1)
        );

        // Now set all fees to zero
        // vm.startPrank(owner);
        CindrToken.setTaxFeePercent(0);
        CindrToken.setBurnFeePercent(0);
        CindrToken.setLiquidityFeePercent(0);
        CindrToken.setMarketingFeePercent(0);
        // vm.stopPrank();

        vm.warp(block.timestamp + 150);

        // Perform a transfer to trigger the fee removal logic
        vm.prank(user1);
        CindrToken.transfer(user2, 500 * 10 ** 9);

        // Debug: Check balances after the second transfer
        console.log(
            "User2 balance after second transfer:",
            CindrToken.balanceOf(user2)
        );
        console.log(
            "User1 balance after second transfer:",
            CindrToken.balanceOf(user1)
        );

        // Perform a second transfer to ensure the fees remain zero
        vm.prank(user1);
        CindrToken.transfer(user2, 500 * 10 ** 9);

        // Debug: Check balances after the third transfer
        console.log(
            "User2 balance after third transfer:",
            CindrToken.balanceOf(user2)
        );
        console.log(
            "User1 balance after third transfer:",
            CindrToken.balanceOf(user1)
        );

        // Assert the fee percentages are zero
        assertEq(CindrToken.taxFee(), 0, "Tax fee should be zero");
        assertEq(CindrToken.burnFee(), 0, "Burn fee should be zero");
        assertEq(CindrToken.liquidityFee(), 0, "Liquidity fee should be zero");
        assertEq(CindrToken.marketingFee(), 0, "Marketing fee should be zero");
    }

    function test_MarketingWalletExcluded() public {
        // Ensure the marketing wallet is excluded from rewards
        // vm.prank(owner);
        CindrToken.excludeFromReward(marketingWallet);

        // Check initial balances
        uint256 initialMarketingWalletBalance = CindrToken.balanceOf(
            marketingWallet
        );
        uint256 initialMarketingWalletRBalance = CindrToken.reflectionFromToken(
            initialMarketingWalletBalance,
            false
        );

        // Transfer tokens to trigger the _takeMarketingFromTAmount function
        uint256 transferAmount = 10_000 * 10 ** 9;
        vm.prank(user1);
        CindrToken.transfer(user2, transferAmount);

        // Check balances after the transfer
        uint256 finalMarketingWalletBalance = CindrToken.balanceOf(
            marketingWallet
        );

        uint256 finalMarketingWalletRBalance = CindrToken.reflectionFromToken(
            finalMarketingWalletBalance,
            false
        );

        // Verify that the marketing wallet's token balance increased correctly
        assertGt(
            finalMarketingWalletBalance,
            initialMarketingWalletBalance,
            "Marketing wallet's token balance should increase"
        );

        // Verify that the marketing wallet's reflection balance increased correctly
        assertGt(
            finalMarketingWalletRBalance,
            initialMarketingWalletRBalance,
            "Marketing wallet's reflection balance should increase"
        );
    }

    // UnReachable condition for reflection token
    function test_MaxTxAmountCondition() public {
        // Ensure swap and liquify is enabled
        CindrToken.setSwapAndLiquifyEnabled(true);

        CindrToken.excludeFromReward(address(user1));
        CindrToken.excludeFromReward(address(CindrToken));

        // Transfer enough tokens to the contract to exceed _maxTxAmount
        uint256 transferAmount = CindrToken._maxTxAmount() -
            CindrToken.balanceOf(address(CindrToken));

        // vm.prank(user1);
        CindrToken.transfer(address(CindrToken), transferAmount);
        // vm.prank(user1);
        CindrToken.transfer(address(CindrToken), transferAmount);

        // Ensure the contract's token balance reaches _maxTxAmount
        uint256 contractTokenBalance = CindrToken.balanceOf(
            address(CindrToken)
        );
        assertGe(
            contractTokenBalance,
            CindrToken._maxTxAmount(),
            "Contract token balance should reach max tx amount"
        );

        // Perform a transfer to trigger the condition
        vm.prank(user1);
        CindrToken.transfer(user2, 1000);

        // Check the final balance to ensure swap and liquify was triggered
        uint256 finalContractTokenBalance = CindrToken.balanceOf(
            address(CindrToken)
        );

        assertLt(
            finalContractTokenBalance,
            contractTokenBalance,
            "Contract token balance should decrease after swap and liquify"
        );
    }
}
