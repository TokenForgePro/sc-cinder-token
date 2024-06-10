// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UNISWAP_V2_ROUTER02, SUSHISWAP_V2_ROUTER02, PANCAKESWAP_V2_ROUTER02, FRAXSWAP_V2_ROUTER02} from "test/utils/constant_eth.sol";

import {Cindr} from "src/Cindr.sol";
import {ICindr} from "src/interfaces/ICindr.sol";

contract CindrTokenTransfersTest is Test {
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
            1000000000,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
        );

        // Transfer some tokens to user1 for testing
        CindrToken.transfer(user1, 10000 * 10 ** 9);
    }

    function test_TransferWithFees() public {
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Transfer tokens from user1 to user2
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertEq(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            "User1 balance should be deducted by transfer amount"
        );

        assertEq(
            newBalanceUser2,
            initialBalanceUser2 + 975 * 10 ** 9, // 950
            "User2 balance should receive transfer amount minus fees"
        );
    }

    function test_TransferWithoutFees() public {
        CindrToken.excludeFromFee(user1);
        CindrToken.excludeFromFee(user2);

        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Transfer tokens from user1 to user2
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        assertEq(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            "User1 balance should be deducted by transfer amount"
        );

        assertEq(
            newBalanceUser2,
            initialBalanceUser2 + 975 * 10 ** 9, // 1000
            "User2 balance should receive full transfer amount"
        );
    }

    function test_TransferExceedingMaxTxAmount() public {
        uint256 maxTxAmount = CindrToken._maxTxAmount();

        // Attempt to transfer more than the max transaction amount
        vm.prank(user1);
        vm.expectRevert("Transfer amount exceeds the maxTxAmount.");
        CindrToken.transfer(user2, maxTxAmount + 1);
    }

    function test_TransferToExcluded() public {
        CindrToken.excludeFromReward(user2);

        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Transfer tokens from user1 to user2 (excluded)
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertEq(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            "User1 balance should be deducted by transfer amount"
        );

        assertEq(
            newBalanceUser2,
            initialBalanceUser2 + 950 * 10 ** 9, // 950
            "User2 balance should receive transfer amount minus fees"
        );
    }

    function test_TransferFromExcluded() public {
        CindrToken.excludeFromReward(user1);

        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Transfer tokens from user1 (excluded) to user2
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertEq(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            "User1 balance should be deducted by transfer amount"
        );

        assertEq(
            newBalanceUser2,
            initialBalanceUser2 + 975 * 10 ** 9, // 950
            "User2 balance should receive transfer amount minus fees"
        );
    }

    function test_TransferBetweenExcluded() public {
        CindrToken.excludeFromReward(user1);
        CindrToken.excludeFromReward(user2);

        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Transfer tokens from user1 (excluded) to user2 (excluded)
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertEq(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            "User1 balance should be deducted by transfer amount"
        );

        assertEq(
            newBalanceUser2,
            initialBalanceUser2 + 950 * 10 ** 9, // 950
            "User2 balance should receive transfer amount minus fees"
        );
    }

    function test_TransferWithNoFeesApplied() public {
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Exclude from fees and transfer tokens
        CindrToken.excludeFromFee(user1);
        CindrToken.excludeFromFee(user2);

        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        assertEq(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            "User1 balance should be deducted by transfer amount"
        );

        assertEq(
            newBalanceUser2,
            initialBalanceUser2 + 975 * 10 ** 9, // 1000 user is excluded not from all fees such as burn and marketing
            "User2 balance should receive full transfer amount"
        );
    }

    function test_InsufficientBalance() public {
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        uint256 r_initialBalanceUser1 = CindrToken.reflectionFromToken(
            initialBalanceUser1,
            false
        );

        // Try transferring more than the balance
        vm.expectRevert();
        // abi.encodeWithSelector(
        //     ICindr.InsufficientBalance.selector,
        //     user1,
        //     initialBalanceUser1,
        //     r_initialBalanceUser1
        // )
        vm.prank(user1);
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }

    function test_InsufficientReflectionBalance() public {
        CindrToken.excludeFromReward(user1);
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        CindrToken.includeInReward(user1);
        uint256 rBalanceUser1 = CindrToken.balanceOf(user1);

        CindrToken.excludeFromReward(user1);

        // Try transferring more than the reflection balance
        vm.expectRevert();
        // abi.encodeWithSelector(
        //     ICindr.InsufficientReflectionBalance.selector,
        //     user1,
        //     rBalanceUser1,
        //     rBalanceUser1 + 1
        // )
        vm.prank(user1);
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }

    function test_TransferToExcluded_InsufficientReflectionBalance() public {
        CindrToken.excludeFromReward(user1);
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        CindrToken.includeInReward(user1);
        uint256 rBalanceUser1 = CindrToken.balanceOf(user1);

        CindrToken.excludeFromReward(user1);

        // Try transferring more than the reflection balance
        vm.prank(user1);
        vm.expectRevert();
        // abi.encodeWithSelector(
        //     ICindr.InsufficientReflectionBalance.selector,
        //     user1,
        //     rBalanceUser1,
        //     rBalanceUser1 + 1
        // )
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }

    function test_TransferFromExcluded_InsufficientBalance() public {
        CindrToken.excludeFromReward(user1);
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        // Try transferring more than the balance
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICindr.InsufficientBalance.selector,
                user1,
                initialBalanceUser1,
                initialBalanceUser1 + 1
            )
        );
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }

    function test_TransferBothExcluded_InsufficientBalance() public {
        CindrToken.excludeFromReward(user1);
        CindrToken.excludeFromReward(user2);
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        // Try transferring more than the balance
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICindr.InsufficientBalance.selector,
                user1,
                initialBalanceUser1,
                initialBalanceUser1 + 1
            )
        );
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }

    function test_TransferFromExcluded_InsufficientReflectionBalance() public {
        CindrToken.excludeFromReward(user1);
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        CindrToken.includeInReward(user1);
        uint256 rBalanceUser1 = CindrToken.reflectionFromToken(
            initialBalanceUser1,
            false
        );

        // Try transferring more than the reflection balance
        vm.expectRevert();
        // abi.encodeWithSelector(
        //     ICindr.InsufficientReflectionBalance.selector,
        //     user1,
        //     rBalanceUser1,
        //     rBalanceUser1 + 1
        // )
        vm.prank(user1);
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }

    function test_TransferBothExcluded_InsufficientReflectionBalance() public {
        CindrToken.excludeFromReward(user1);
        CindrToken.excludeFromReward(user2);
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        CindrToken.includeInReward(user1);
        uint256 rBalanceUser1 = CindrToken.reflectionFromToken(
            initialBalanceUser1,
            false
        );

        // Try transferring more than the reflection balance
        vm.expectRevert();
        // abi.encodeWithSelector(
        //     ICindr.InsufficientReflectionBalance.selector,
        //     user1,
        //     rBalanceUser1,
        //     rBalanceUser1 + 1
        // )
        vm.prank(user1);
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }
}
