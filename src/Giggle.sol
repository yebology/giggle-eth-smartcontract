// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {GiggleService} from "./GiggleService.sol";

contract Giggle {
    //
    GiggleService private i_giggleService;

    constructor() {
        i_giggleService = new GiggleService();
    }

    function registerWallet(string memory _postId) external {
        i_giggleService.registerWallet(_postId, msg.sender);
    }

    function createProposalRequest(
        string memory _postId,
        uint256 _daysEstimationForCompletion,
        address _buyer,
        uint256 _finalFee
    ) external {
        i_giggleService.createProposalRequest(
            _postId,
            _daysEstimationForCompletion,
            _buyer,
            _finalFee
        );
    }

    function acceptProposalRequest(uint256 _proposalId) external payable {
        i_giggleService.acceptProposalRequest(_proposalId, msg.sender);
    }

    function finishOrder(uint256 _orderId) external {
        i_giggleService.finishOrder(_orderId, msg.sender);
    }

    function approveFinishedOrder(uint256 _orderId) external {
        i_giggleService.approveFinishedOrder(_orderId, msg.sender);
    }

    function withdrawFunds(uint256 _orderId) external {
        i_giggleService.withdrawFunds(_orderId, msg.sender);
    }

    function returnFunds(uint256 _orderId) external {
        i_giggleService.returnFunds(_orderId, msg.sender);
    }

    //
}
