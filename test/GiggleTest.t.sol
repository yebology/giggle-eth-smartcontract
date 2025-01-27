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
    string private constant orderId = "061asdfa";
    uint256 private additionalTime = 1 seconds;

    function setUp() public {
        GiggleScript giggleScript = new GiggleScript();
        giggle = giggleScript.run();
    }

    function testSuccessfullyCreateOrderRequest() public {
        hoax(ALICE, 0.5 ether);
        uint256 orderDeadline = block.timestamp + additionalTime;
        giggle.createOrderRequest{value: 0.5 ether}(orderId, BOB, orderDeadline);
        uint256 expectedEthAmountInSmartContract = 0.5 ether;
        uint256 actualEthAmountInSmartContract = giggle.getGiggleServiceContractAddress().balance;
        bool expectedOrderExistence = true;
        bool actualOrderExistence = giggle.checkOrderIdExistence(orderId);
        assert(expectedOrderExistence == actualOrderExistence);
        assertEq(expectedEthAmountInSmartContract, actualEthAmountInSmartContract);
    }

    function testRevertIfInvalidOrderInput() public {
        hoax(ALICE, 0.5 ether);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidOrderInput.selector));
        giggle.createOrderRequest{value: 0.5 ether}(orderId, BOB, 0);
    }

    function testRevertIfDataRedundantDetected() public {
        testSuccessfullyCreateOrderRequest();
        hoax(ALICE, 0.5 ether);
        uint256 orderDeadline = block.timestamp + 1 seconds;
        vm.expectRevert(abi.encodeWithSelector(GiggleService.DataRedundantDetected.selector));
        giggle.createOrderRequest{value: 0.5 ether}(orderId, BOB, orderDeadline);
    }

    function testSuccessfullyFinishedOrder() public {
        testSuccessfullyCreateOrderRequest();
        vm.startPrank(BOB);
        giggle.finishOrder(orderId);
        vm.stopPrank();
    }

    function testSuccessfullyApproveFinishedOrder() public {
        testSuccessfullyFinishedOrder();
        vm.startPrank(ALICE);
        giggle.approveFinishedOrder(orderId);
        vm.stopPrank();
    }

    function testRevertIfInvalidOrderStatus() public {
        testSuccessfullyCreateOrderRequest();
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidOrderStatus.selector));
        giggle.approveFinishedOrder(orderId);
        vm.stopPrank();
    }

    function testRevertIfInvalidAuthorizationFromOrderApprover() public {
        testSuccessfullyFinishedOrder();
        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.InvalidAuthorization.selector));
        giggle.approveFinishedOrder(orderId);
        vm.stopPrank();
    }

    function testSuccessfullyWithdrawFunds() public {
        testSuccessfullyApproveFinishedOrder();
        vm.startPrank(BOB);
        uint256 expectedUserBalanceBeforeWithdraw = 0 ether;
        uint256 actualUserBalanceBeforeWithdraw = BOB.balance;
        uint256 expectedSmartContractBalanceBeforeWithdraw = 0.5 ether;
        uint256 actualSmartContractBalanceBeforeWithdraw = giggle.getGiggleServiceContractAddress().balance;
        giggle.withdrawFunds(orderId);
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

    function testSuccessfullyReturnFunds() public {
        additionalTime = 0 seconds;
        testSuccessfullyCreateOrderRequest();
        vm.startPrank(ALICE);
        uint256 expectedUserBalanceBeforeRefund = 0 ether;
        uint256 actualUserBalanceBeforeRefund = ALICE.balance;
        uint256 expectedSmartContractBalanceBeforeRefund = 0.5 ether;
        uint256 actualSmartContractBalanceBeforeRefund = giggle.getGiggleServiceContractAddress().balance;
        giggle.returnFunds(orderId);
        uint256 expectedUserBalanceAfterRefund = 0.5 ether;
        uint256 actualUserBalanceAfterRefund = ALICE.balance;
        uint256 expectedSmartContractBalanceAfterRefund = 0 ether;
        uint256 actualSmartContractBalanceAfterRefund = giggle.getGiggleServiceContractAddress().balance;
        assertEq(expectedUserBalanceAfterRefund, actualUserBalanceAfterRefund);
        assertEq(expectedUserBalanceBeforeRefund, actualUserBalanceBeforeRefund);
        assertEq(expectedSmartContractBalanceAfterRefund, actualSmartContractBalanceAfterRefund);
        assertEq(expectedSmartContractBalanceBeforeRefund, actualSmartContractBalanceBeforeRefund);
        vm.stopPrank();
    }

    function testSuccessfullyRevertIfRefundNotAllowed() public {
        testSuccessfullyCreateOrderRequest();
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(GiggleService.RefundNotAllowed.selector));
        giggle.returnFunds(orderId);
        vm.stopPrank();
    }
    //
}
