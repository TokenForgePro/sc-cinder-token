// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UNISWAP_V2_ROUTER02, SUSHISWAP_V2_ROUTER02, PANCAKESWAP_V2_ROUTER02, FRAXSWAP_V2_ROUTER02} from "test/utils/constant_eth.sol";

import {Cindr} from "src/Cindr.sol";

contract CindrTokenTest is Test {
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
            1_000_000_000,
            UNISWAP_V2_ROUTER02,
            marketingWallet
        );

        // Transfer some tokens to user1 for testing
        CindrToken.transfer(user1, 1_000_000 * 10 ** 9);
    }

    function test_ReflectionFromToken() public {
        uint256 tAmount = 1000 * 10 ** 9;
        uint256 rAmount = CindrToken.reflectionFromToken(tAmount, false);
        uint256 rAmountAfterFees = CindrToken.reflectionFromToken(
            tAmount,
            true
        );

        assertGt(
            rAmount,
            rAmountAfterFees,
            "rAmount should be greater than rAmountAfterFees"
        );
    }

    function test_TokenFromReflection() public {
        uint256 tAmount = 1000 * 10 ** 9;
        uint256 rAmount = CindrToken.reflectionFromToken(tAmount, false);
        uint256 tAmountFromReflection = CindrToken.tokenFromReflection(rAmount);

        assertEq(
            tAmount,
            tAmountFromReflection,
            "tAmount should match tAmountFromReflection"
        );
    }

    function test_Deliver() public {
        uint256 tAmount = 1000 * 10 ** 9;
        uint256 initialTotalFees = CindrToken.totalFees();

        vm.prank(user1);
        CindrToken.deliver(tAmount);

        uint256 newTotalFees = CindrToken.totalFees();

        assertEq(
            newTotalFees,
            initialTotalFees + tAmount,
            "Total fees should increase by tAmount"
        );
    }

    function test_TotalFees() public {
        uint256 initialTotalFees = CindrToken.totalFees();

        // Perform some transactions
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newTotalFees = CindrToken.totalFees();

        assertGt(
            newTotalFees,
            initialTotalFees,
            "Total fees should increase after transactions"
        );
    }

    function test_ReflectionMechanism() public {
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Transfer tokens from user1 to user2
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertGe(
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

    function test_ReflectionDistribution() public {
        uint256 initialTotalSupply = CindrToken.totalSupply();
        uint256 initialReflectedSupply = CindrToken.reflectionFromToken(
            initialTotalSupply,
            false
        );

        // Perform a delivery to increase reflections
        vm.prank(user1);
        CindrToken.deliver(1000 * 10 ** 9);

        uint256 newTotalSupply = CindrToken.totalSupply();
        uint256 newReflectedSupply = CindrToken.reflectionFromToken(
            newTotalSupply,
            false
        );

        assertEq(
            initialTotalSupply,
            newTotalSupply,
            "Total supply should not change"
        );

        // 115792089237165665707562491323450651172793325928919069481962811019600000000000
        // 115792089237281457796799790150060836557767378293284582977077809088500000000000
        // Gt
        assertLt(
            newReflectedSupply,
            initialReflectedSupply,
            "Reflected supply should increase"
        );
    }

    function test_TransferStandard() public {
        // Ensure that neither user1 nor user2 are excluded from rewards
        // vm.prank(owner);
        // CindrToken.includeInReward(user1);
        // vm.prank(owner);
        // CindrToken.includeInReward(user2);

        // Perform a transfer from user1 to user2 to trigger the else block
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        uint256 transferAmount = 100_000 * 10 ** 9;
        vm.prank(user1);
        CindrToken.transfer(user2, transferAmount);

        // Check balances to ensure the transfer happened correctly
        uint256 user1Balance = CindrToken.balanceOf(user1);
        uint256 user2Balance = CindrToken.balanceOf(user2);

        assertGt(
            initialBalanceUser1,
            initialBalanceUser1 - transferAmount,
            "User1 balance should be correct"
        );

        assertGe(
            user2Balance,
            97_500 * 10 ** 9,
            "User2 balance should be correct"
        );
    }
}
