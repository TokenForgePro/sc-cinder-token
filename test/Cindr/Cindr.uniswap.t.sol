// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UNISWAP_V2_ROUTER02} from "test/utils/constant_eth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Cindr} from "src/Cindr.sol";

contract CindrUniswapTest is Test {
    Cindr CindrToken;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address owner;
    address marketingWallet;
    address user1;
    address user2;
    address user3;

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
        user3 = makeAddr("user3");

        uint256 totalSupply = 1_000_000_000 * 10 ** 9;

        // Deploy the Cindr token contract with the Uniswap router
        CindrToken = new Cindr(
            "Cindr",
            "CND",
            totalSupply,
            UNISWAP_V2_ROUTER02,
            marketingWallet
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
        // CindrToken.transfer(user3, totalSupply / 3);
    }

    function test_SwapAndLiquify_Internal() public {
        uint256 tokenAmount = 1_000_000 * 10 ** 9;

        uint256 initialContractTokenBalance = CindrToken.balanceOf(
            address(CindrToken)
        );
        uint256 initialEthBalance = address(CindrToken).balance;

        console.log(
            "Initial contract token balance:",
            initialContractTokenBalance
        );
        console.log("Initial contract ETH balance:", initialEthBalance);

        for (uint256 index = 0; index < 400; index++) {
            vm.startPrank(user1);
            CindrToken.transfer(user2, tokenAmount);
            vm.stopPrank();

            vm.warp(block.timestamp + 1);

            uint256 currentContractTokenBalance = CindrToken.balanceOf(
                address(CindrToken)
            );
            uint256 currentEthBalance = address(CindrToken).balance;

            console.log(
                "Transfer",
                index,
                "contract token balance:",
                currentContractTokenBalance
            );
            console.log(
                "Transfer",
                index,
                "contract ETH balance:",
                currentEthBalance
            );

            //   Contract will swap and liquify at this point
            //   Transfer 240 contract token balance: 5005055518749998
            //   Transfer 240 contract ETH balance: 0
            //   Transfer 241 contract token balance: 110578569364046
            //   Transfer 241 contract ETH balance: 0
        }

        uint256 finalContractTokenBalance = CindrToken.balanceOf(
            address(CindrToken)
        );
        uint256 finalEthBalance = address(CindrToken).balance;

        console.log("Final contract token balance:", finalContractTokenBalance);
        console.log("Final contract ETH balance:", finalEthBalance);

        assertGe(
            finalEthBalance,
            initialEthBalance,
            "ETH balance should increase after swap and liquify"
        );

        assertLt(
            finalContractTokenBalance,
            initialContractTokenBalance,
            "Token balance should decrease after swap and liquify"
        );
    }

    function test_TakeLiquidity() public {
        // Exclude the contract from rewards

        uint256 initialContractTokenBalance = CindrToken.balanceOf(
            address(CindrToken)
        );

        CindrToken.transfer(owner, 1_000_000 * 10 ** 9);

        uint256 tokenAmount = 10_000 * 10 ** 9; // Some token amount for liquidity

        // Transfer tokens to the contract to ensure it has a balance
        vm.prank(owner);
        CindrToken.transfer(user1, tokenAmount);

        // Perform a transfer to trigger the liquidity mechanism
        vm.prank(owner);
        CindrToken.transfer(user1, tokenAmount);

        uint256 currentContractTokenBalance = CindrToken.balanceOf(
            address(CindrToken)
        );

        assertLt(
            currentContractTokenBalance,
            initialContractTokenBalance,
            "Contract should not own more tokens after liquidity take"
        );
    }
}
