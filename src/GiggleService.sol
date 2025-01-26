// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

contract GiggleService {
    //
    enum OrderStatus {
        PAID,
        FINISHED,
        APPROVED,
        FEE_WITHDRAWED,
        FAILED
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

    mapping(string postId => address owner) private s_postOwnerWallet;
    mapping(address buyer => mapping(uint256 orderId => uint256 fund)) private s_fundsFromBuyer;

    Proposal[] private s_proposals;
    Order[] private s_orders;

    error InvalidPostIdOrWalletInput();
    error InvalidProposalInput();
    error InvalidPaymentAmount();
    error InvalidAuthorization();
    error ExistenceFundsDetected();
    error InvalidOrderStatus();
    error InvalidWithdrawAction();

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

    modifier checkPostOwnerAuthorization(uint256 _orderId, address _caller) {
        uint256 proposalId = s_orders[_orderId].proposalId;
        string memory postId = s_proposals[proposalId].postId;
        address expectedOwner = s_postOwnerWallet[postId];
        if (expectedOwner != _caller) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkUserAuthorization(uint256 _proposalId, address _caller) {
        address expectedBuyer = s_proposals[_proposalId].buyer;
        if (expectedBuyer != _caller) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkApproverAuthorization(uint256 _orderId, address _caller) {
        uint256 proposalId = s_orders[_orderId].proposalId;
        address expectedApprover = s_proposals[proposalId].buyer;
        if (expectedApprover != _caller) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkOrderStatus(uint256 _orderId, OrderStatus expectedStatus) {
        OrderStatus status = s_orders[_orderId].status;
        if (status != expectedStatus) {
            revert InvalidOrderStatus();
        }
        _;
    }

    modifier checkWithdrawStatus(uint256 _orderId, OrderStatus expectedStatus) {
        OrderStatus status = s_orders[_orderId].status;
        uint256 orderTimestamp = s_orders[_orderId].orderAcceptedAt;
        uint256 proposalId = s_orders[_orderId].proposalId;
        uint256 daysEstimation = s_proposals[proposalId].daysEstimationForCompletion * 1 days;
        if (status != expectedStatus && block.timestamp < orderTimestamp + daysEstimation) {
            revert InvalidWithdrawAction();
        }
        _;
    }

    // done test
    function registerWallet(string memory _postId, address _wallet)
        external
        checkPostIdAndWalletInput(_postId, _wallet)
    {
        s_postOwnerWallet[_postId] = _wallet;
    }

    function createProposalRequest(
        string memory _postId,
        uint256 _daysEstimationForCompletion,
        address _buyer,
        uint256 _finalFee
    ) external checkPostIdAndWalletInput(_postId, _buyer) {
        _addNewProposal(_postId, _daysEstimationForCompletion, _buyer, _finalFee);
    }

    function acceptProposalRequest(uint256 _proposalId, address _user)
        external
        payable
        checkUserAuthorization(_proposalId, _user)
        checkPaymentAmount(_proposalId, msg.value)
    {
        _placeFunds(_proposalId, _user, msg.value);
        _addNewOrder(_proposalId);
    }

    function finishOrder(uint256 _orderId, address _owner)
        external
        checkPostOwnerAuthorization(_orderId, _owner)
        checkOrderStatus(_orderId, OrderStatus.PAID)
    {
        s_orders[_orderId].status = OrderStatus.FINISHED;
    }

    function approveFinishedOrder(uint256 _orderId, address _approver)
        external
        checkApproverAuthorization(_orderId, _approver)
        checkOrderStatus(_orderId, OrderStatus.FINISHED)
    {
        s_orders[_orderId].status = OrderStatus.APPROVED;
    }

    function withdrawFunds(uint256 _orderId, address _owner)
        external
        checkPostOwnerAuthorization(_orderId, _owner)
        checkWithdrawStatus(_orderId, OrderStatus.APPROVED)
    {
        _withdraw(_orderId, _owner);
    }

    function returnFunds(uint256 _orderId, address _user) external {
        _refund(_orderId, _user);
    }

    function _addNewProposal(
        string memory _postId,
        uint256 _daysEstimationForCompletion,
        address _buyer,
        uint256 _finalFee
    ) private {
        s_proposals.push(
            Proposal({
                proposalId: s_proposals.length,
                postId: _postId,
                buyer: _buyer,
                daysEstimationForCompletion: _daysEstimationForCompletion,
                finalFee: _finalFee
            })
        );
    }

    function _addNewOrder(uint256 _proposalId) private {
        s_orders.push(
            Order({
                orderId: s_orders.length,
                proposalId: _proposalId,
                orderAcceptedAt: block.timestamp,
                status: OrderStatus.PAID
            })
        );
    }

    function _withdraw(uint256 _orderId, address _owner) private {
        uint256 proposalId = s_orders[_orderId].proposalId;
        uint256 withdrawAmount = s_proposals[proposalId].finalFee;
        bool success = _transferFunds(_owner, withdrawAmount);
        if (success) {
            s_orders[_orderId].status = OrderStatus.FEE_WITHDRAWED;
        }
    }

    function _refund(uint256 _orderId, address _user) private {
        uint256 proposalId = s_orders[_orderId].proposalId;
        uint256 amount = s_proposals[proposalId].finalFee;
        bool success = _transferFunds(_user, amount);
        if (success) {
            s_orders[_orderId].status = OrderStatus.FAILED;
        }
    }

    function _placeFunds(uint256 _orderId, address _buyer, uint256 _amount) private {
        bool success = _transferFunds(address(this), _amount);
        if (success) {
            s_fundsFromBuyer[_buyer][_orderId] = msg.value;
        }
    }

    function _transferFunds(address _recipient, uint256 _amount) private returns (bool) {
        address payable recipient = payable(address(_recipient));
        (bool success,) = recipient.call{value: _amount}("");
        return success;
    }
    //
}
