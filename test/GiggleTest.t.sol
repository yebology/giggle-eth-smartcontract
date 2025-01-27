// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Giggle} from "../src/Giggle.sol";
import {GiggleScript} from "../script/GiggleScript.s.sol";
import {GiggleService} from "../src/GiggleService.sol";

contract GiggleTest is Test {
    //
    Giggle private giggle;
    address private constant BOB = address(1);
    address private constant ALICE = address(2);

    function setUp() public {
        GiggleScript giggleScript = new GiggleScript();
        giggle = giggleScript.run();
    }

    function testSuccessfullyRegisterWallet() public {
        vm.startPrank(BOB);
        string memory postId = "061asdfa";
        giggle.registerWallet(postId);
        address expectedOwner = giggle.getPostOwner(postId);
        assert(expectedOwner == BOB);
        vm.stopPrank();
    }

    function testRevertIfInvalidPostIdOrWalletInput() public {
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidPostIdOrWalletInput.selector));
        giggle.registerWallet("");
        vm.stopPrank();
    }

    function testSuccessfullyCreateProposalRequest() public {
        testSuccessfullyRegisterWallet();
        vm.startPrank(BOB);
        string memory postId = "061asdfa";
        uint256 daysEstimationForCompletion = 0;
        address buyer = ALICE;
        uint256 finalFee = 0.5 ether;
        giggle.createProposalRequest(postId, daysEstimationForCompletion, buyer, finalFee);
        uint256 expectedProposalsTotal = 1;
        uint256 actualProposalsTotal = giggle.getProposals().length;
        assertEq(expectedProposalsTotal, actualProposalsTotal);
        vm.stopPrank();
    }

    function testRevertIfInvalidAuthorizationForPostOwner() public {
        testSuccessfullyRegisterWallet();
        vm.startPrank(ALICE);
        string memory postId = "061asdfa";
        uint256 daysEstimationForCompletion = 10;
        address buyer = BOB;
        uint256 finalFee = 0.5 ether;
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidAuthorization.selector));
        giggle.createProposalRequest(postId, daysEstimationForCompletion, buyer, finalFee);
        vm.stopPrank();
    }

    function testSuccessfullyAcceptProposalRequest() public {
        testSuccessfullyCreateProposalRequest();
        hoax(ALICE, 0.5 ether);
        giggle.acceptProposalRequest{value: 0.5 ether}(0);
        uint256 expectedEthAmountInSmartContract = 0.5 ether;
        uint256 actualEthAmountInSmartContract = giggle.getGiggleServiceContractAddress().balance;
        uint256 expectedOrdersTotal = 1;
        uint256 actualOrdersTotal = giggle.getOrders().length;
        assertEq(expectedOrdersTotal, actualOrdersTotal);
        assertEq(expectedEthAmountInSmartContract, actualEthAmountInSmartContract);
    }

    function testRevertIfInvalidUserAuthorization() public {
        testSuccessfullyCreateProposalRequest();
        hoax(BOB, 0.5 ether);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidAuthorization.selector));
        giggle.acceptProposalRequest{value: 0.5 ether}(0);
    }

    function testRevertIfInvalidPaymentAmount() public {
        testSuccessfullyCreateProposalRequest();
        hoax(ALICE, 0.6 ether);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidPaymentAmount.selector));
        giggle.acceptProposalRequest{value: 0.6 ether}(0);
    }

    function testSuccessfullyFinishedOrder() public {
        testSuccessfullyAcceptProposalRequest();
        vm.startPrank(BOB);
        giggle.finishOrder(0);
        vm.stopPrank();
    }

    function testSuccessfullyApproveFinishedOrder() public {
        testSuccessfullyFinishedOrder();
        vm.startPrank(ALICE);
        giggle.approveFinishedOrder(0);
        vm.stopPrank();
    }

    function testRevertIfInvalidOrderStatus() public {
        testSuccessfullyAcceptProposalRequest();
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidOrderStatus.selector));
        giggle.approveFinishedOrder(0);
        vm.stopPrank();
    }

    function testRevertIfInvalidAuthorizationFromOrderApprover() public {
        testSuccessfullyFinishedOrder();
        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidAuthorization.selector));
        giggle.approveFinishedOrder(0);
        vm.stopPrank();
    }

    function testSuccessfullyWithdrawFunds() public {
        testSuccessfullyFinishedOrder();
        vm.startPrank(BOB);
        uint256 expectedUserBalanceBeforeWithdraw = 0 ether;
        uint256 actualUserBalanceBeforeWithdraw = BOB.balance;
        uint256 expectedSmartContractBalanceBeforeWithdraw = 0.5 ether;
        uint256 actualSmartContractBalanceBeforeWithdraw = giggle.getGiggleServiceContractAddress().balance;
        giggle.withdrawFunds(0);
        uint256 expectedUserBalanceAfterWithdraw = 0.5 ether;
        uint256 actualUserBalanceAfterWithdraw = BOB.balance;
        uint256 expectedSmartContractBalanceAfterWithdraw = 0 ether;
        uint256 actualSmartContractBalanceAfterWithdraw = giggle.getGiggleServiceContractAddress().balance;
        assertEq(expectedUserBalanceAfterWithdraw, actualUserBalanceAfterWithdraw);
        assertEq(expectedUserBalanceBeforeWithdraw, actualUserBalanceBeforeWithdraw);
        assertEq(expectedSmartContractBalanceAfterWithdraw, actualSmartContractBalanceAfterWithdraw);
        assertEq(expectedSmartContractBalanceBeforeWithdraw, actualSmartContractBalanceBeforeWithdraw);
        vm.stopPrank();
    }
    //
}
