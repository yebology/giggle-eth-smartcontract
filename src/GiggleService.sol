// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GiggleService is Ownable, ReentrancyGuard {
    //
    enum OrderStatus {
        PAID,
        FINISHED,
        APPROVED,
        FEE_WITHDRAWED,
        FAILED_AND_REFUNDED
    }
    enum Role {
        BUYER,
        SELLER
    }

    mapping(string orderId => bool isExistence) s_orderExistence;

    mapping(string orderId => address buyer) s_orderToBuyer;
    mapping(string orderId => address seller) s_orderToSeller;

    mapping(string orderId => OrderStatus status) s_orderStatus;
    mapping(string orderId => uint256 deadlineTimestamp) s_orderDeadlineTimestamp;
    mapping(string orderId => uint256 fee) s_orderFees;

    error InvalidOrderInput();
    error DataRedundantDetected();
    error RefundNotAllowed();
    error InvalidAuthorization();
    error InvalidOrderStatus();

    constructor(address _owner) Ownable(_owner) {}

    modifier checkOrderInput(
        string memory _orderId,
        address _caller,
        address _seller,
        uint256 _deadlineTimestamp,
        uint256 _amount
    ) {
        if (
            bytes(_orderId).length == 0 || _caller == address(0) || _seller == address(0) || _caller == _seller
                || _deadlineTimestamp < block.timestamp || _amount == 0
        ) {
            revert InvalidOrderInput();
        }
        _;
    }

    modifier checkDoubleData(string memory _orderId) {
        if (s_orderExistence[_orderId]) {
            revert DataRedundantDetected();
        }
        _;
    }

    modifier checkAuthorization(string memory _orderId, address _caller, Role _expectedRole) {
        if (
            (_expectedRole == Role.SELLER && s_orderToSeller[_orderId] != _caller)
                || (_expectedRole == Role.BUYER && s_orderToBuyer[_orderId] != _caller)
        ) {
            revert InvalidAuthorization();
        }
        _;
    }

    modifier checkOrderStatus(string memory _orderId, OrderStatus _expectedStatus) {
        OrderStatus status = s_orderStatus[_orderId];
        if (status != _expectedStatus) {
            revert InvalidOrderStatus();
        }
        _;
    }

    modifier checkRefundEligibity(string memory _orderId) {
        OrderStatus status = s_orderStatus[_orderId];
        uint256 deadline = s_orderDeadlineTimestamp[_orderId];
        if (status != OrderStatus.PAID || block.timestamp < deadline) {
            revert RefundNotAllowed();
        }
        _;
    }

    function createOrderRequest(string memory _orderId, address _caller, address _seller, uint256 _deadlineTimestamp)
        external
        payable
        onlyOwner
        checkOrderInput(_orderId, _caller, _seller, _deadlineTimestamp, msg.value)
        checkDoubleData(_orderId)
    {
        _addNewOrder(_orderId, _caller, _seller, _deadlineTimestamp);
        _placeFunds(_orderId, msg.value);
    }

    function finishOrder(string memory _orderId, address _seller)
        external
        onlyOwner
        checkAuthorization(_orderId, _seller, Role.SELLER)
        checkOrderStatus(_orderId, OrderStatus.PAID)
    {
        _changeOrderStatus(_orderId, OrderStatus.FINISHED);
    }

    function approveFinishedOrder(string memory _orderId, address _buyer)
        external
        onlyOwner
        checkAuthorization(_orderId, _buyer, Role.BUYER)
        checkOrderStatus(_orderId, OrderStatus.FINISHED)
    {
        _changeOrderStatus(_orderId, OrderStatus.APPROVED);
    }

    function withdrawFunds(string memory _orderId, address _seller)
        external
        onlyOwner
        checkAuthorization(_orderId, _seller, Role.SELLER)
        checkOrderStatus(_orderId, OrderStatus.APPROVED)
    {
        _handleFunds(_orderId, _seller, OrderStatus.FEE_WITHDRAWED);
    }

    function returnFunds(string memory _orderId, address _buyer)
        external
        onlyOwner
        checkAuthorization(_orderId, _buyer, Role.BUYER)
        checkRefundEligibity(_orderId)
    {
        _handleFunds(_orderId, _buyer, OrderStatus.FAILED_AND_REFUNDED);
    }

    function checkOrderIdExistence(string memory _orderId) external view returns (bool) {
        return s_orderExistence[_orderId];
    }

    function _addNewOrder(string memory _orderId, address _caller, address _seller, uint256 _deadlineTimestamp)
        private
    {
        s_orderExistence[_orderId] = true;
        s_orderToBuyer[_orderId] = _caller;
        s_orderToSeller[_orderId] = _seller;
        s_orderStatus[_orderId] = OrderStatus.PAID;
        s_orderDeadlineTimestamp[_orderId] = _deadlineTimestamp;
    }

    function _changeOrderStatus(string memory _orderId, OrderStatus _newStatus) private {
        s_orderStatus[_orderId] = _newStatus;
    }

    function _updateFundsFromBuyer(string memory _orderId, uint256 _newAmount) private {
        s_orderFees[_orderId] = _newAmount;
    }

    function _handleFunds(string memory _orderId, address _to, OrderStatus _newOrderStatus) private {
        uint256 amount = s_orderFees[_orderId];
        bool success = _transferFunds(_to, amount);
        if (success) {
            _changeOrderStatus(_orderId, _newOrderStatus);
        }
    }

    function _placeFunds(string memory _orderId, uint256 _amount) private {
        bool success = _transferFunds(address(this), _amount);
        if (success) {
            _updateFundsFromBuyer(_orderId, _amount);
        }
    }

    function _transferFunds(address _recipient, uint256 _amount) private nonReentrant returns (bool) {
        address payable recipient = payable(address(_recipient));
        (bool success,) = recipient.call{value: _amount}("");
        return success;
    }

    receive() external payable {}

    fallback() external payable {}
    //
}
