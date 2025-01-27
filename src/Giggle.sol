// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {GiggleService} from "./GiggleService.sol";
import {GiggleHire} from "./GiggleHire.sol";

contract Giggle {
    //
    GiggleService private immutable giggleService;
    GiggleHire private immutable giggleHire;

    constructor() {
        giggleService = new GiggleService(address(this));
        giggleHire = new GiggleHire(address(this));
    }

    function createOrderRequest(string memory _orderId, address _seller, uint256 _deadlineTimestamp) external payable {
        giggleService.createOrderRequest{value: msg.value}(_orderId, msg.sender, _seller, _deadlineTimestamp);
    }

    function finishOrder(string memory _orderId) external {
        giggleService.finishOrder(_orderId, msg.sender);
    }

    function approveFinishedOrder(string memory _orderId) external {
        giggleService.approveFinishedOrder(_orderId, msg.sender);
    }

    function withdrawFunds(string memory _orderId) external {
        giggleService.withdrawFunds(_orderId, msg.sender);
    }

    function returnFunds(string memory _orderId) external {
        giggleService.returnFunds(_orderId, msg.sender);
    }

    function checkOrderIdExistence(string memory _orderId) external view returns (bool) {
        return giggleService.checkOrderIdExistence(_orderId);
    }

    function getGiggleServiceContractAddress() external view returns (address) {
        return address(giggleService);
    }
    //
}
