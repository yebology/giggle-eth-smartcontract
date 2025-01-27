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

    function registerWallet(string memory _postId) external {
        giggleService.registerWallet(_postId, msg.sender);
    }

    function createProposalRequest(
        string memory _postId,
        uint256 _daysEstimationForCompletion,
        address _buyer,
        uint256 _finalFee
    ) external {
        giggleService.createProposalRequest(_postId, _daysEstimationForCompletion, _buyer, _finalFee, msg.sender);
    }

    function acceptProposalRequest(uint256 _proposalId) external payable {
        giggleService.acceptProposalRequest{value: msg.value}(_proposalId, msg.sender);
    }

    function finishOrder(uint256 _orderId) external {
        giggleService.finishOrder(_orderId, msg.sender);
    }

    function approveFinishedOrder(uint256 _orderId) external {
        giggleService.approveFinishedOrder(_orderId, msg.sender);
    }

    function withdrawFunds(uint256 _orderId) external {
        giggleService.withdrawFunds(_orderId, msg.sender);
    }

    function returnFunds(uint256 _orderId) external {
        giggleService.returnFunds(_orderId, msg.sender);
    }

    function getPostOwner(string memory _postId) external view returns (address) {
        return giggleService.getPostOwner(_postId);
    }

    function getFundsFromBuyer(uint256 _orderId) external view returns (uint256) {
        return giggleService.getFundsFromBuyer(_orderId);
    }

    function getProposals() external view returns (GiggleService.Proposal[] memory) {
        return giggleService.getProposals();
    }

    function getOrders() external view returns (GiggleService.Order[] memory) {
        return giggleService.getOrders();
    }

    function getGiggleServiceContractAddress() external view returns (address) {
        return address(giggleService);
    }
    //
}
