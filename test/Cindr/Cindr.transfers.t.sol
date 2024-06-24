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
    address user3;

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
        user3 = makeAddr("user3");

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

    function test_TransferWithFees() public {
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        // Transfer tokens from user1 to user2
        vm.prank(user1);
        CindrToken.transfer(user2, 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceUser2 = CindrToken.balanceOf(user2);

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertApproxEqAbs(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            150
        );

        assertEq(
            newBalanceUser2,
            initialBalanceUser2 + 975 * 10 ** 9, // 950
            "User2 balance should receive transfer amount minus fees"
        );
    }

    function testRevert_InsufficientBalance() public {
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        uint256 r_initialBalanceUser1 = CindrToken.reflectionFromToken(
            initialBalanceUser1,
            false
        );

        // Try transferring more than the balance
        vm.expectRevert();
        vm.prank(user1);
        CindrToken.transfer(user2, initialBalanceUser1 + 1);
    }

    function test_TransferToExcluded() public {
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 initialBalanceContract = CindrToken.balanceOf(
            address(CindrToken)
        );

        // Transfer tokens from user1 to excluded contract
        vm.prank(user1);
        CindrToken.transfer(address(CindrToken), 1000 * 10 ** 9);

        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);
        uint256 newBalanceContract = CindrToken.balanceOf(address(CindrToken));

        assertApproxEqAbs(
            newBalanceUser1,
            initialBalanceUser1 - 1000 * 10 ** 9,
            15 * 10 ** 9
        );

        assertApproxEqAbs(
            newBalanceContract,
            initialBalanceContract + 1000 * 10 ** 9,
            15 * 10 ** 9
        );
    }

    function test_TransferFromExcluded() public {
        uint256 initialBalanceContract = CindrToken.balanceOf(
            address(CindrToken)
        );
        uint256 initialBalanceUser1 = CindrToken.balanceOf(user1);

        // Transfer tokens from excluded contract to user1
        vm.prank(address(CindrToken));
        CindrToken.transfer(user1, 500 * 10 ** 9);

        uint256 newBalanceContract = CindrToken.balanceOf(address(CindrToken));
        uint256 newBalanceUser1 = CindrToken.balanceOf(user1);

        assertApproxEqAbs(
            newBalanceUser1,
            initialBalanceUser1 + 500 * 10 ** 9,
            15 * 10 ** 9
        );
    }

    function test_TransferBothExcluded() public {
        uint256 initialBalanceContract = CindrToken.balanceOf(
            address(CindrToken)
        );
        uint256 initialBalanceUniswap = CindrToken.balanceOf(
            UNISWAP_V2_ROUTER02
        );

        vm.prank(address(CindrToken));
        CindrToken.transfer(UNISWAP_V2_ROUTER02, 500 * 10 ** 9); // Transfer from excluded contract to Uniswap pair

        uint256 newBalanceContract = CindrToken.balanceOf(address(CindrToken));
        uint256 newBalanceUniswap = CindrToken.balanceOf(UNISWAP_V2_ROUTER02);

        assertApproxEqAbs(
            newBalanceUniswap,
            initialBalanceUniswap + 500 * 10 ** 9,
            15 * 10 ** 9
        );
    }

    function test_TransferBetweenExcluded() public {
        uint256 initialBalanceUniswapV2Pair = CindrToken.balanceOf(
            uniswapV2Pair
        );
        uint256 initialBalanceCindrToken = CindrToken.balanceOf(
            address(CindrToken)
        );

        // Transfer tokens from user1 (excluded) to user2 (excluded)
        vm.prank(user1);
        CindrToken.transfer(address(uniswapV2Pair), 2000 * 10 ** 9);

        vm.prank(uniswapV2Pair);
        CindrToken.transfer(address(CindrToken), 1000 * 10 ** 9);

        uint256 newBalanceUniswapV2Pair = CindrToken.balanceOf(uniswapV2Pair);
        uint256 newBalanceCindrToken = CindrToken.balanceOf(
            address(CindrToken)
        );

        uint256 totalFees = 50 * 10 ** 9; // 5% total fees

        assertApproxEqAbs(
            newBalanceCindrToken,
            initialBalanceCindrToken + 1000 * 10 ** 9, // 950
            15 * 10 ** 9
        );
    }

    function test_InsufficientReflectionBalance() public {
        // CindrToken.excludeFromReward(user1);
        uint256 initialBalanceUniswapV2Pair = CindrToken.balanceOf(
            uniswapV2Pair
        );

        // CindrToken.includeInReward(user1);
        uint256 rBalanceUser1 = CindrToken.balanceOf(user1);

        // CindrToken.excludeFromReward(user1);

        // Try transferring more than the reflection balance
        vm.expectRevert();
        // abi.encodeWithSelector(
        //     ICindr.InsufficientReflectionBalance.selector,
        //     uniswapV2Pair,
        //     rBalanceUser1,
        //     rBalanceUser1 + 1
        // )
        vm.prank(uniswapV2Pair);
        CindrToken.transfer(uniswapV2Pair, initialBalanceUniswapV2Pair + 1);
    }
}
