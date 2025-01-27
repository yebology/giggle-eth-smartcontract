// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GiggleService is Ownable {
    //
    enum OrderStatus {
        PAID,
        FINISHED,
        APPROVED,
        FEE_WITHDRAWED,
        FAILED_AND_REFUNDED
    }

    struct Proposal {
        uint256 proposalId;
        string postId;
        address buyer;
        uint256 finalFee;
        uint256 daysEstimationForCompletion;
    }

    struct Order {
        uint256 orderId;
        uint256 proposalId;
        uint256 orderAcceptedAt;
        OrderStatus status;
    }

    Proposal[] private s_proposals;
    Order[] private s_orders;

    mapping(string postId => address owner) private s_postOwnerWallet;
    mapping(address buyer => mapping(uint256 orderId => uint256 fund)) private s_fundsFromBuyer;

    error InvalidPostIdOrWalletInput();
    error InvalidProposalInput();
    error InvalidPaymentAmount();
    error InvalidAuthorization();
    error ExistenceFundsDetected();
    error InvalidOrderStatus();
    error InvalidWithdrawOrRefundAction();

    constructor(address _owner) Ownable(_owner) {}

    modifier checkPostIdAndWalletInput(string memory _postId, address _wallet) {
        if (bytes(_postId).length == 0 || _wallet == address(0)) {
            revert InvalidPostIdOrWalletInput();
        }
        _;
    }

    modifier checkPaymentAmount(uint256 _proposalId, uint256 _amount) {
        uint256 serviceFee = s_proposals[_proposalId].finalFee;
        if (_amount != serviceFee) {
            revert InvalidPaymentAmount();
        }
        _;
    }

    modifier checkFundExistence(address _buyer, uint256 _orderId) {
        uint256 funds = s_fundsFromBuyer[_buyer][_orderId];
        if (funds != 0) {
            revert ExistenceFundsDetected();
        }
        _;
    }

    modifier checkPostOwnerAuthorization(string memory _postId, address _caller) {
        address expectedOwner = s_postOwnerWallet[_postId];
        if (expectedOwner != _caller) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkPostOwnerAuthorizationFromProposal(uint256 _orderId, address _caller) {
        uint256 proposalId = s_orders[_orderId].proposalId;
        string memory postId = s_proposals[proposalId].postId;
        address expectedOwner = s_postOwnerWallet[postId];
        if (expectedOwner != _caller) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkUserAuthorization(uint256 _proposalId, address _caller) {
        address expectedCaller = s_proposals[_proposalId].buyer;
        if (expectedCaller != _caller) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkBuyerAuthorization(uint256 _orderId, address _caller) {
        uint256 proposalId = s_orders[_orderId].proposalId;
        address expectedApprover = s_proposals[proposalId].buyer;
        if (expectedApprover != _caller) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkOrderStatus(uint256 _orderId, OrderStatus _expectedStatus) {
        OrderStatus status = s_orders[_orderId].status;
        if (status != _expectedStatus) {
            revert InvalidOrderStatus();
        }
        _;
    }

    modifier checkAdditionalStepStatus(uint256 _orderId, OrderStatus _expectedStatus) {
        OrderStatus status = s_orders[_orderId].status;
        uint256 orderTimestamp = s_orders[_orderId].orderAcceptedAt;
        uint256 proposalId = s_orders[_orderId].proposalId;
        uint256 daysEstimation = s_proposals[proposalId].daysEstimationForCompletion * 1 days;
        if (status != _expectedStatus && block.timestamp < (orderTimestamp + daysEstimation)) {
            revert InvalidWithdrawOrRefundAction();
        }
        _;
    }

    // done test
    function registerWallet(string memory _postId, address _wallet)
        external
        onlyOwner
        checkPostIdAndWalletInput(_postId, _wallet)
    {
        s_postOwnerWallet[_postId] = _wallet;
    }

    // done test
    function createProposalRequest(
        string memory _postId,
        uint256 _daysEstimationForCompletion,
        address _buyer,
        uint256 _finalFee,
        address _caller
    ) external onlyOwner checkPostIdAndWalletInput(_postId, _buyer) checkPostOwnerAuthorization(_postId, _caller) {
        _addNewProposal(_postId, _daysEstimationForCompletion, _buyer, _finalFee);
    }

    // done test
    function acceptProposalRequest(uint256 _proposalId, address _user)
        external
        payable
        onlyOwner
        checkUserAuthorization(_proposalId, _user)
        checkPaymentAmount(_proposalId, msg.value)
    {
        _placeFunds(_proposalId, _user, msg.value);
        _addNewOrder(_proposalId);
    }

    // done test
    function finishOrder(uint256 _orderId, address _owner)
        external
        onlyOwner
        checkPostOwnerAuthorizationFromProposal(_orderId, _owner)
        checkOrderStatus(_orderId, OrderStatus.PAID)
    {
        _changeOrderStatus(_orderId, OrderStatus.FINISHED);
    }

    // done test
    function approveFinishedOrder(uint256 _orderId, address _approver)
        external
        onlyOwner
        checkBuyerAuthorization(_orderId, _approver)
        checkOrderStatus(_orderId, OrderStatus.FINISHED)
    {
        _changeOrderStatus(_orderId, OrderStatus.APPROVED);
    }

    // done test
    function withdrawFunds(uint256 _orderId, address _owner)
        external
        onlyOwner
        checkPostOwnerAuthorizationFromProposal(_orderId, _owner)
        checkAdditionalStepStatus(_orderId, OrderStatus.APPROVED)
    {
        _handleFunds(_orderId, _owner, OrderStatus.FEE_WITHDRAWED);
    }

    // done test
    function returnFunds(uint256 _orderId, address _user)
        external
        onlyOwner
        checkBuyerAuthorization(_orderId, _user)
        checkAdditionalStepStatus(_orderId, OrderStatus.PAID)
    {
        _handleFunds(_orderId, _user, OrderStatus.FAILED_AND_REFUNDED);
    }

    // done test
    function getPostOwner(string memory _postId) external view onlyOwner returns (address) {
        return s_postOwnerWallet[_postId];
    }

    // done test
    function getFundsFromBuyer(uint256 _orderId) external view onlyOwner returns (uint256) {
        return s_fundsFromBuyer[msg.sender][_orderId];
    }

    // done test
    function getProposals() external view onlyOwner returns (Proposal[] memory) {
        return s_proposals;
    }

    // done test
    function getOrders() external view onlyOwner returns (Order[] memory) {
        return s_orders;
    }

    function _addNewProposal(
        string memory _postId,
        uint256 _daysEstimationForCompletion,
        address _buyer,
        uint256 _finalFee
    ) private {
        uint256 proposalId = s_proposals.length;
        s_proposals.push(Proposal(proposalId, _postId, _buyer, _finalFee, _daysEstimationForCompletion));
    }

    function _addNewOrder(uint256 _proposalId) private {
        uint256 orderId = s_orders.length;
        s_orders.push(Order(orderId, _proposalId, block.timestamp, OrderStatus.PAID));
    }

    function _changeOrderStatus(uint256 _orderId, OrderStatus _status) private {
        s_orders[_orderId].status = _status;
    }

    function _updateFundsFromBuyer(address _buyer, uint256 _orderId, uint256 _newAmount) private {
        s_fundsFromBuyer[_buyer][_orderId] = _newAmount;
    }

    function _handleFunds(uint256 _orderId, address _to, OrderStatus _newOrderStatus) private {
        uint256 proposalId = s_orders[_orderId].proposalId;
        uint256 amount = s_proposals[proposalId].finalFee;
        address buyer = s_proposals[proposalId].buyer;
        bool success = _transferFunds(_to, amount);
        if (success) {
            _updateFundsFromBuyer(buyer, _orderId, 0);
            _changeOrderStatus(_orderId, _newOrderStatus);
        }
    }

    function _placeFunds(uint256 _orderId, address _buyer, uint256 _amount) private {
        bool success = _transferFunds(address(this), _amount);
        if (success) {
            _updateFundsFromBuyer(_buyer, _orderId, _amount);
        }
    }

    function _transferFunds(address _recipient, uint256 _amount) private returns (bool) {
        address payable recipient = payable(address(_recipient));
        (bool success,) = recipient.call{value: _amount}("");
        return success;
    }

    receive() external payable {}

    fallback() external payable {}
    //
}
