// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {GiggleService} from "./GiggleService.sol";

contract Giggle {
    //
    GiggleService private immutable giggleService;

    constructor() {
        giggleService = new GiggleService();
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
        giggleService.createProposalRequest(
            _postId,
            _daysEstimationForCompletion,
            _buyer,
            _finalFee
        );
    }

    function acceptProposalRequest(uint256 _proposalId) external payable {
        giggleService.acceptProposalRequest(_proposalId, msg.sender);
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

    //
}
