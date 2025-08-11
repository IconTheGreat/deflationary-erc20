//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MyDeflationaryToken} from "src/MyDeflationaryToken.sol";
import {Test} from "forge-std/Test.sol";

contract MyDeflationaryTokenTest is Test {
    MyDeflationaryToken public myToken;
    address icon = address(this);
    address burner = address(0);
    address alice = address(3);
    address bob = address(4);
    address treasuryWallet = address(1);
    address hodlersDistributionWallet = address(2);
    uint256 transferFee = 10;
    uint256 burnPercent = 5;
    uint256 treasuryPercent = 3;
    uint256 hodlersPercent = 2;
    uint256 PRECISION = 10_000;

    function setUp() public {
        myToken = new MyDeflationaryToken(treasuryWallet, hodlersDistributionWallet, 10, 5, 3, 2);
    }

    // mint tests

    function test_owner_can_call_mint() public {
        address to = address(1);
        myToken.mint(to, 200);
    }

    function test_revert_none_owner_cant_call() public {
        vm.prank(alice);
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__NotOwner.selector);
        myToken.mint(bob, 200);
    }

    function test_revert_CantBeZeroAddressInMint() public {
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__CantBeZeroAddress.selector);
        myToken.mint(burner, 100);
    }

    function testBalanceUpdateInMint() public {
        myToken.mint(alice, 100);
        uint256 balance = myToken.balanceOf(alice);
        assertEq(100, balance);
    }

    //constructor tests

    function test_revert_AllFeesMustSumUpToTransferFee() public {
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__AllFeesMustSumUpToTransferFee.selector);
        myToken = new MyDeflationaryToken(treasuryWallet, hodlersDistributionWallet, 1000, 500, 100, 200);
    }

    function test_revert_CantExceedMaxTransferFee() public {
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__CantExceedMaxTransferFee.selector);
        myToken = new MyDeflationaryToken(treasuryWallet, hodlersDistributionWallet, 1500, 1000, 300, 200);
    }

    //transfer tests

    function test_expect_revert__LesserBalance_In_Transfer() public {
        myToken.mint(alice, 100);
        vm.prank(alice);
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__LesserBalance.selector);
        myToken.transfer(bob, 200);
    }

    function test_transfer_works_fine() public {
        myToken.mint(alice, 100);
        vm.prank(alice);
        myToken.transfer(bob, 100);
    }

    function test_balance_update_after_transfers() public {
        myToken.mint(alice, 200);
        vm.prank(alice);
        myToken.transfer(bob, 100);
        uint256 balance = myToken.balanceOf(alice);
        assertEq(balance, 100);
    }

    function test_total_supply() public {
        myToken.mint(bob, 1000);
        uint256 supply = myToken.totalSupply();
        assertEq(supply, 1000);
    }

    function test_fuzz_transferfee_calculations(uint256 mintAmount, uint256 transferAmount) public {
        // Bound values to 1,000,000 to avoid overflow and ensure valid transfers
        mintAmount = bound(mintAmount, 1, 1_000_000);
        transferAmount = bound(transferAmount, 1, mintAmount);

        // Mint tokens to Alice
        myToken.mint(alice, mintAmount);

        // Transfer from Alice to Bob
        vm.prank(alice);
        myToken.transfer(bob, transferAmount);

        // ---- Fee calculations ----
        uint256 fee = (transferAmount * transferFee) / PRECISION;
        uint256 netAmount = transferAmount - fee;
        uint256 expectedTreasury = (fee * treasuryPercent) / transferFee;
        uint256 burned = (fee * burnPercent) / transferFee;
        uint256 expectedHodlers = fee - expectedTreasury - burned; // remainder to hodlers

        // ---- Assertions ----
        // Bob's balance after fees
        assertEq(myToken.balanceOf(bob), netAmount, "Bob received wrong amount");

        // Treasury wallet balance
        assertEq(myToken.balanceOf(treasuryWallet), expectedTreasury, "Treasury balance mismatch");

        // Hodlers distribution wallet balance
        assertEq(myToken.balanceOf(hodlersDistributionWallet), expectedHodlers, "Hodlers balance mismatch");

        // Total supply after burn
        uint256 expectedSupply = mintAmount - burned;
        assertEq(myToken.totalSupply(), expectedSupply, "Total supply mismatch");

        // Invariant: net + treasury + hodlers + burned == transferAmount
        assertEq(netAmount + expectedTreasury + expectedHodlers + burned, transferAmount, "Fee math broken");
    }

    //approval tests

    function test_approval() public {
        myToken.mint(bob, 100);
        vm.startPrank(bob);
        myToken.approve(icon, 50);
        vm.stopPrank();
        myToken.transferFrom(bob, alice, 50);
    }

    function test_revert_when_not_approved() public {
        myToken.mint(bob, 100);
        vm.startPrank(bob);
        myToken.approve(icon, 50);
        vm.stopPrank();
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__NotApprovedForThisAmount.selector);
        myToken.transferFrom(bob, alice, 100);
    }

    function test_allowance() public {
        myToken.mint(bob, 100);
        vm.startPrank(bob);
        myToken.approve(icon, 50);
        vm.stopPrank();
        uint256 allowance = myToken.allowance(bob, icon);
        assertEq(allowance, 50);
    }

    //edge cases

    function test_revert_sender_or_receiver_cant_be_zero() public {
        myToken.mint(bob, 100);
        vm.startPrank(bob);
        myToken.approve(icon, 50);
        vm.stopPrank();
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__CantBeZeroAddress.selector);
        myToken.transferFrom(bob, burner, 50);
    }

    function test_revert_receiver_zero_address() public {
        myToken.mint(bob, 100);
        vm.prank(bob);
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__CantBeZeroAddress.selector);
        myToken.transfer(burner, 50);
    }

    function test_revert__LesserBalance_In_TransferFrom() public {
        myToken.mint(bob, 500);
        vm.startPrank(bob);
        myToken.approve(icon, 1000);
        vm.stopPrank();
        vm.expectRevert(MyDeflationaryToken.MyDeflationaryToken__LesserBalance.selector);
        myToken.transferFrom(bob, alice, 1000);
    }
}
