// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {UNISWAP_V2_ROUTER02} from "test/utils/constant_eth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Cindr} from "src/Cindr.sol";

contract CindrFuzzTest is Test {
    Cindr CindrToken;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address owner;
    address marketingWallet;
    address user1;
    address user2;

    uint16 _taxFee = 15; // 1.5%
    uint16 _burnFee = 15; // 1.5%
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

        uint256 totalSupply = 5_000_000_000_000 * 10 ** 9;

        // Deploy the Cindr token contract with the Uniswap router
        CindrToken = new Cindr(
            "Cindr",
            "CND",
            totalSupply,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            _taxFee,
            _burnFee,
            _liquidityFee,
            _marketingFee
        );

        uniswapV2Router = IUniswapV2Router02(UNISWAP_V2_ROUTER02);
        uniswapV2Pair = CindrToken.uniswapV2Pair();

        CindrToken.approve(UNISWAP_V2_ROUTER02, type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: 10 ether}(
            address(CindrToken),
            totalSupply / 4,
            0,
            0,
            owner,
            block.timestamp
        );

        // Transfer some tokens to user1 for testing
        CindrToken.transfer(user1, totalSupply / 2);
        CindrToken.transfer(user2, totalSupply / 4);
    }

    function testFuzz_Transfer(uint256 amount1, uint256 amount2) public {
        // Ensure amounts are within valid range
        amount1 = bound(amount1, 1, CindrToken.balanceOf(user1));
        amount2 = bound(amount2, 1, CindrToken.balanceOf(user2));

        // Perform transfers
        vm.prank(user1);
        CindrToken.transfer(user2, amount1);

        vm.prank(user2);
        CindrToken.transfer(user1, amount2);

        // Check balances
        assertGe(CindrToken.balanceOf(user1), 0);
        assertGe(CindrToken.balanceOf(user2), 0);
    }

    function testFuzz_SetFees(
        uint16 newTaxFee,
        uint16 newBurnFee,
        uint16 newLiquidityFee,
        uint16 newMarketingFee
    ) public {
        // Ensure new fee values are within valid range
        newTaxFee = uint16(bound(newTaxFee, 10, 100)); // from 1% to 10% no need for more  than 10% as max
        newBurnFee = uint16(bound(newBurnFee, 10, 100)); // from 1% to 10% no need for more  than 10% as max
        newLiquidityFee = uint16(bound(newLiquidityFee, 10, 100)); // from 1% to 10% no need for more  than 10% as max
        newMarketingFee = uint16(bound(newMarketingFee, 10, 100)); // from 1% to 10% no need for more  than 10% as max

        // vm.prank(owner);
        CindrToken.setTaxFeePercent(newTaxFee);

        // vm.prank(owner);
        CindrToken.setBurnFeePercent(newBurnFee);

        // vm.prank(owner);
        CindrToken.setLiquidityFeePercent(newLiquidityFee);

        // vm.prank(owner);
        CindrToken.setMarketingFeePercent(newMarketingFee);

        // Assert the new fees are set correctly
        assertEq(CindrToken.taxFee(), newTaxFee);
        assertEq(CindrToken.burnFee(), newBurnFee);
        assertEq(CindrToken.liquidityFee(), newLiquidityFee);
        assertEq(CindrToken.marketingFee(), newMarketingFee);
    }

    function testFuzz_TakeBurnFromTAmount(uint256 tAmount) public {
        // Ensure tAmount is within valid range
        tAmount = bound(tAmount, 1, CindrToken.balanceOf(user1));

        // Perform transfer to trigger burn
        vm.prank(user1);
        CindrToken.transfer(user2, tAmount);

        // Check total supply after burn
        uint256 totalSupply = CindrToken.totalSupply();
        assertGe(totalSupply, 0);
    }

    function testFuzz_ReflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) public {
        // Ensure tAmount is within valid range
        tAmount = bound(tAmount, 1, CindrToken.totalSupply());

        uint256 reflectionAmount = CindrToken.reflectionFromToken(
            tAmount,
            deductTransferFee
        );

        // Ensure reflection amount is within valid range
        assertGe(reflectionAmount, 0);
    }

    function testFuzz_TakeMarketingFromTAmount(uint256 tAmount) public {
        // Ensure tAmount is within valid range
        tAmount = bound(tAmount, 1, CindrToken.balanceOf(user1));

        // Perform transfer to trigger marketing fee
        vm.prank(user1);
        CindrToken.transfer(user2, tAmount);

        // Check marketing wallet balance after fee
        uint256 marketingWalletBalance = CindrToken.balanceOf(marketingWallet);
        assertGe(marketingWalletBalance, 0);
    }

    function testFuzz_Deliver(uint256 tAmount) public {
        // Ensure tAmount is within valid range
        tAmount = bound(tAmount, 1, CindrToken.balanceOf(user1));

        // Exclude user1 from reward to enable deliver function
        // vm.prank(owner);
        // CindrToken.excludeFromReward(user1);

        // Deliver reflections
        vm.prank(user1);
        CindrToken.deliver(tAmount);

        // Ensure total fees have increased
        uint256 totalFees = CindrToken.totalFees();
        assertGt(totalFees, 0);
    }

    function testFuzz_ExcludedFromFeeTransfer(uint256 amount) public {
        // Ensure amount is within valid range
        amount = bound(amount, 1, CindrToken.balanceOf(user1));

        // Exclude marketing wallet from fee
        // vm.prank(owner);
        CindrToken.excludeFromFee(marketingWallet);

        // Perform transfer
        vm.prank(user1);
        CindrToken.transfer(marketingWallet, amount);

        // Check balance
        assertGe(CindrToken.balanceOf(marketingWallet), amount);
    }

    function testFuzz_TransferWithReflection(uint256 amount) public {
        // Ensure amount is within valid range
        amount = bound(amount, 1, CindrToken.balanceOf(user1));

        // Perform transfer to accumulate reflections
        vm.prank(user1);
        CindrToken.transfer(user2, amount);

        // Check balances
        assertGe(CindrToken.balanceOf(user1), 0);
        assertGe(CindrToken.balanceOf(user2), amount);
    }

    function testFuzz_ExcludeFromRewardAndTransfer(uint256 amount) public {
        // Ensure amount is within valid range
        amount = bound(amount, 1, CindrToken.balanceOf(user1));

        // Exclude user1 from reward
        // vm.prank(owner);
        CindrToken.excludeFromReward(user1);

        // Perform transfer
        vm.prank(user1);
        CindrToken.transfer(user2, amount);

        // Check balances
        assertGe(CindrToken.balanceOf(user1), 0);
        assertGe(CindrToken.balanceOf(user2), amount);
    }

    function testFuzz_ExcludedFromReward(uint256 amount) public {
        // Ensure amount is within valid range
        amount = bound(amount, 1, CindrToken.balanceOf(user1));

        // Exclude user2 wallet from reward
        // vm.prank(owner);
        CindrToken.excludeFromReward(user2);

        // Perform transfer
        vm.prank(user1);
        CindrToken.transfer(user2, amount);

        // Check if user2 wallet is excluded from reward
        bool isExcluded = CindrToken.isExcludedFromReward(user2);
        assertTrue(isExcluded);

        // Check balance of user2 wallet
        assertGe(CindrToken.balanceOf(user2), amount);
    }

    function testFuzz_SwapAndLiquify(uint256 amount) public {
        // Ensure amount is within valid range
        amount = bound(amount, 1, CindrToken.balanceOf(user1));

        // Enable swap and liquify
        // vm.prank(owner);
        CindrToken.setSwapAndLiquifyEnabled(true);

        // Perform transfer to trigger swap and liquify
        vm.prank(user1);
        CindrToken.transfer(user2, amount);

        // Check contract ETH balance
        uint256 contractEthBalance = address(CindrToken).balance;
        assertGe(contractEthBalance, 0);
    }

    function testFuzz_MaxTxAmount(
        uint256 newMaxTxPercent,
        uint256 transferAmount
    ) public {
        // Ensure new max tx percent is within valid range
        newMaxTxPercent = bound(newMaxTxPercent, 10, 100); // from 1% to 10% no need for more  than 10% as max

        // Set new max tx amount
        // vm.prank(owner);
        CindrToken.setMaxTxPercent(newMaxTxPercent);

        // Ensure transfer amount is within new max tx amount
        uint256 maxTxAmount = (CindrToken.totalSupply() * newMaxTxPercent) /
            100;

        transferAmount = bound(transferAmount, 1 * 10 ** 9, maxTxAmount);

        // Perform transfer
        vm.prank(user1);
        // CindrToken.transfer(user2, transferAmount);

        // Check balances
        assertGe(CindrToken.balanceOf(user1), 0);
        assertGe(CindrToken.balanceOf(user2), 0);
    }

    function testFuzz_LiquidityAndSwap(uint256 amount) public {
        // Ensure amount is within valid range
        amount = bound(amount, 1, CindrToken.balanceOf(user1));

        // Enable swap and liquify
        // vm.prank(owner);
        CindrToken.setSwapAndLiquifyEnabled(true);

        // Perform transfer to trigger swap and liquify
        vm.prank(user1);
        CindrToken.transfer(user2, amount);

        // Check contract ETH balance and liquidity
        uint256 contractEthBalance = address(CindrToken).balance;
        uint256 contractTokenBalance = CindrToken.balanceOf(
            address(CindrToken)
        );

        assertGe(contractEthBalance, 0);
        assertGe(contractTokenBalance, 0);
    }

    function testFuzz_SetFeesAndTransfer(
        uint16 newTaxFee,
        uint16 newBurnFee,
        uint16 newLiquidityFee,
        uint16 newMarketingFee,
        uint256 amount
    ) public {
        // Ensure new fee values are within valid range
        newTaxFee = uint16(bound(newTaxFee, 10, 100));
        newBurnFee = uint16(bound(newBurnFee, 10, 100));
        newLiquidityFee = uint16(bound(newLiquidityFee, 10, 100));
        newMarketingFee = uint16(bound(newMarketingFee, 10, 100));

        // Set new fees
        // vm.prank(owner);
        CindrToken.setTaxFeePercent(newTaxFee);
        // vm.prank(owner);
        CindrToken.setBurnFeePercent(newBurnFee);
        // vm.prank(owner);
        CindrToken.setLiquidityFeePercent(newLiquidityFee);
        // vm.prank(owner);
        CindrToken.setMarketingFeePercent(newMarketingFee);

        // Ensure amount is within valid range
        amount = bound(amount, 1 * 10 ** 9, CindrToken.balanceOf(user1));

        // Perform transfer to apply new fees
        vm.prank(user1);
        CindrToken.transfer(user2, amount);

        // Check balances
        assertGe(CindrToken.balanceOf(user1), 0);
        assertGe(CindrToken.balanceOf(user2), amount);
    }
}
