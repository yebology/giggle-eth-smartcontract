// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Giggle {
    //
    enum ActionCategory {
        DEPOSIT,
        SETTLEMENT
    }

    mapping(string postId => uint256 fee) private s_serviceFee;
    mapping(string postId => address wallet) private s_postCreatorWallet;
    mapping(address buyer => mapping(string postId => uint256 depositAmount))
        private s_buyerDepositAmount;
    mapping(ActionCategory actionCategory => uint8 numerator) private s_actionCategoryNumerator;

    error InvalidPostInput();
    error ExistenceDepositDetected();
    error NonExistenceDepositDetected();
    error InvalidPaymentAmount();

    constructor () {
        s_actionCategoryNumerator[ActionCategory.DEPOSIT] = 3;
        s_actionCategoryNumerator[ActionCategory.SETTLEMENT] = 7;
    }

    modifier checkPostInput(string memory _postId, uint256 _fee) {
        if (bytes(_postId).length == 0 || _fee <= 0) {
            revert InvalidPostInput();
        }
        _;
    }

    modifier checkDepositExistence(
        string memory _postId,
        address _buyer,
        ActionCategory _actionCategory
    ) {
        uint256 depositAmount = s_buyerDepositAmount[_buyer][_postId];
        if (_actionCategory == ActionCategory.DEPOSIT && depositAmount != 0) {
            revert ExistenceDepositDetected();
        }
        else if (
            _actionCategory == ActionCategory.SETTLEMENT && depositAmount == 0
        ) {
            revert NonExistenceDepositDetected();
        }
        _;
    }

    modifier checkPaymentAmount(
        string memory _postId,
        uint256 _amount,
        ActionCategory _actionCategory
    ) {
        uint256 serviceFee = s_serviceFee[_postId];
        uint8 numerator = s_actionCategoryNumerator[_actionCategory];
        uint256 expectedDepositAmount = (serviceFee * numerator) / 10;
        if (_amount != expectedDepositAmount) {
            revert InvalidPaymentAmount();
        }
        _;
    }

    function registerPost(
        string memory _postId,
        uint256 _fee
    ) external checkPostInput(_postId, _fee) {
        s_serviceFee[_postId] = _fee;
        s_postCreatorWallet[_postId] = msg.sender;
    }

    function updateServiceFee(
        string memory _postId,
        uint256 _newFee
    ) external checkPostInput(_postId, _newFee) {
        s_serviceFee[_postId] = _newFee;
    }

    function addDeposit(
        string memory _postId
    )
        external
        payable
        checkDepositExistence(_postId, msg.sender, ActionCategory.DEPOSIT)
        checkPaymentAmount(_postId, msg.value, ActionCategory.DEPOSIT)
    {
        s_buyerDepositAmount[msg.sender][_postId] = msg.value;
    }

    function settlePayment(
        string memory _postId
    )
        external
        payable
        checkDepositExistence(_postId, msg.sender, ActionCategory.SETTLEMENT)
        checkPaymentAmount(_postId, msg.value, ActionCategory.SETTLEMENT)
    {}

    function withdrawFunds() external payable {}

    function returnFunds() external {}
    //
}
