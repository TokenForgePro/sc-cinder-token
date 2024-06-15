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
    address spender;

    uint16 _taxFee = 15; // 1.5%
    uint16 _burnFee = 15; //  1.5%
    uint16 _liquidityFee = 10; // 1%
    uint16 _marketingFee = 10; // 1%

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        owner = makeAddr("owner");

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        spender = makeAddr("spender");

        marketingWallet = makeAddr("marketingWallet");

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
        CindrToken.transfer(user1, 100_000 * 10 ** 9);
    }

    function test_SetupTokenName() public {
        string memory name = CindrToken.name();
        assertEq(name, "Cindr", "Token name should be 'Cindr'");
    }

    function test_SetupTokenSymbol() public {
        string memory symbol = CindrToken.symbol();
        assertEq(symbol, "CND", "Token symbol should be 'CND'");
    }

    function test_SetupDecimals() public {
        uint16 decimals = CindrToken.decimals();
        assertEq(decimals, 9, "Token decimals should be 9");
    }

    function test_SetupTotalSupply() public {
        uint256 totalSupply = CindrToken.totalSupply();

        uint256 expectedSupply = 1_000_000_000 * 10 ** 6 * 10 ** 9;
        assertLt(
            totalSupply,
            expectedSupply,
            "Total supply should not match the initial supply"
        );
    }

    function test_SetupOwner() public {
        address contractOwner = CindrToken.owner();
        assertEq(
            contractOwner,
            address(this),
            "Contract owner should be the deployer"
        );
    }

    function test_SetupMarketingWallet() public {
        address _marketingWallet = CindrToken.marketingWallet();
        assertEq(
            _marketingWallet,
            marketingWallet,
            "Marketing wallet should be set correctly"
        );
    }

    function test_SetupFees() public {
        uint16 taxFee = CindrToken.taxFee();
        uint16 burnFee = CindrToken.burnFee();
        uint16 liquidityFee = CindrToken.liquidityFee();
        uint16 marketingFee = CindrToken.marketingFee();

        assertEq(taxFee, _taxFee, "Tax fee should be set to 1");
        assertEq(burnFee, _burnFee, "Burn fee should be set to 1");
        assertEq(
            liquidityFee,
            _liquidityFee,
            "Liquidity fee should be set to 1"
        );
        assertEq(
            marketingFee,
            _marketingFee,
            "Marketing fee should be set to 1"
        );
    }

    function test_InitialBalance() public {
        uint256 ownerBalance = CindrToken.balanceOf(address(this));

        uint256 expectedBalance = 1_000_000_000 * 10 ** 6 * 10 ** 9;

        assertLe(
            ownerBalance,
            expectedBalance,
            "Deployer should have less than total supply initially"
        );
    }

    function test_RevertName() public {
        vm.expectRevert(bytes("Token name cannot be empty"));
        new Cindr(
            "",
            "CND",
            1000000000,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            1,
            1,
            1,
            1
        );
    }

    function test_RevertSymbol() public {
        vm.expectRevert(bytes("Token symbol cannot be empty"));
        new Cindr(
            "Cindr",
            "",
            1000000000,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
        );
    }

    function test_RevertTotalSupply() public {
        vm.expectRevert(bytes("Total supply must be greater than zero"));
        new Cindr(
            "Cindr",
            "CND",
            0,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
        );
    }

    function test_RevertUniswapV2RouterAddress() public {
        vm.expectRevert(
            bytes("UniswapV2Router address cannot be zero address")
        );
        new Cindr(
            "Cindr",
            "CND",
            1000000000,
            address(0),
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
        );
    }

    function test_RevertMarketingWalletAddress() public {
        vm.expectRevert(
            bytes("Marketing wallet address cannot be zero address")
        );
        new Cindr(
            "Cindr",
            "CND",
            1000000000,
            UNISWAP_V2_ROUTER02,
            address(0),
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
        );
    }

    function test_RevertTaxFee() public {
        vm.expectRevert(bytes("Tax fee must be between 0 and 10%"));
        new Cindr(
            "Cindr",
            "CND",
            1000000000,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            1001, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
        );
    }

    function test_RevertBurnFee() public {
        vm.expectRevert(bytes("Burn fee must be between 0 and 10%"));
        new Cindr(
            "Cindr",
            "CND",
            1000000000,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            1001, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            _marketingFee // _marketingFee 1%
        );
    }

    function test_RevertLiquidityFee() public {
        vm.expectRevert(bytes("Liquidity fee must be between 0 and 10%"));
        new Cindr(
            "Cindr",
            "CND",
            1000000000,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            1001,
            _marketingFee // _marketingFee 1%
        );
    }

    function test_RevertMarketingFee() public {
        vm.expectRevert(bytes("Marketing fee must be between 0 and 10%"));
        new Cindr(
            "Cindr",
            "CND",
            1000000000,
            UNISWAP_V2_ROUTER02,
            marketingWallet,
            _taxFee, // _taxFee 1.5%
            _burnFee, // _burnFee 1.5%
            _liquidityFee, // _liquidityFee 1%
            1001
        );
    }

    function testAllowance() public {
        uint256 amount = 1_000 * 10 ** 9;
        vm.prank(user1);
        CindrToken.approve(spender, amount);

        uint256 allowance = CindrToken.allowance(user1, spender);
        assertEq(
            allowance,
            amount,
            "Allowance should be equal to approved amount"
        );
    }

    function testApprove() public {
        uint256 amount = 1_000 * 10 ** 9;
        vm.prank(user1);
        bool success = CindrToken.approve(spender, amount);

        assertTrue(success, "Approve should return true");
        uint256 allowance = CindrToken.allowance(user1, spender);
        assertEq(
            allowance,
            amount,
            "Allowance should be equal to approved amount"
        );
    }

    function testTransferFrom() public {
        uint256 amount = 10_000 * 10 ** 9;
        uint256 initialBalanceUser2 = CindrToken.balanceOf(user2);

        vm.prank(user1);
        CindrToken.approve(spender, amount);

        vm.prank(spender);
        bool success = CindrToken.transferFrom(user1, user2, amount);

        assertTrue(success, "TransferFrom should return true");
        uint256 finalBalanceUser2 = CindrToken.balanceOf(user2);

        assertLt(
            finalBalanceUser2,
            initialBalanceUser2 + amount,
            "Balance of user2 should be decreased by the tax fee"
        );
    }

    function testIncreaseAllowance() public {
        uint256 amount = 1_000 * 10 ** 9;
        vm.prank(user1);
        CindrToken.approve(spender, amount);

        vm.prank(user1);
        bool success = CindrToken.increaseAllowance(spender, amount);

        assertTrue(success, "IncreaseAllowance should return true");
        uint256 allowance = CindrToken.allowance(user1, spender);
        assertEq(
            allowance,
            2 * amount,
            "Allowance should be increased by the specified amount"
        );
    }

    function testDecreaseAllowance() public {
        uint256 amount = 1_000 * 10 ** 9;
        vm.prank(user1);
        CindrToken.approve(spender, amount);

        vm.prank(user1);
        bool success = CindrToken.decreaseAllowance(spender, amount / 2);

        assertTrue(success, "DecreaseAllowance should return true");
        uint256 allowance = CindrToken.allowance(user1, spender);
        assertEq(
            allowance,
            amount / 2,
            "Allowance should be decreased by the specified amount"
        );
    }

    function test_RecoverETH_Success() public {
        // Send some ETH to the contract
        vm.deal(address(CindrToken), 10 ether);

        // Check the contract balance before recovery
        uint256 contractBalanceBefore = address(CindrToken).balance;
        assertEq(
            contractBalanceBefore,
            10 ether,
            "Contract should have 10 ether balance"
        );

        // Check owner's balance before recovery
        uint256 ownerBalanceBefore = address(this).balance;

        // Recover ETH
        // vm.prank(owner);
        CindrToken.recoverETH();

        // Check the contract balance after recovery
        uint256 contractBalanceAfter = address(CindrToken).balance;
        assertEq(
            contractBalanceAfter,
            0,
            "Contract balance should be 0 after recovery"
        );

        // Check owner's balance after recovery
        uint256 ownerBalanceAfter = address(this).balance;
        assertEq(
            ownerBalanceAfter,
            ownerBalanceBefore + 10 ether,
            "Owner should have recovered 10 ether"
        );
    }

    function test_RecoverETH_NoETHToRecover() public {
        // Ensure contract has no ETH
        assertEq(
            address(CindrToken).balance,
            0,
            "Contract balance should be 0"
        );

        // Attempt to recover ETH and expect revert
        // vm.prank(owner);
        vm.expectRevert("No ETH to recover");
        CindrToken.recoverETH();
    }

    function test_RecoverETH_OnlyOwner() public {
        // Send some ETH to the contract
        vm.deal(address(CindrToken), 10 ether);

        // Attempt to recover ETH from a non-owner address and expect revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        vm.prank(user1);
        CindrToken.recoverETH();
    }

    fallback() external payable {}
}
