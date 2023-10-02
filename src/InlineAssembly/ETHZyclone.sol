// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.13;

import "./Zyclone.sol";

contract ETHZyclone is Zyclone {
    constructor(
        IDepositVerifier _depositVerifier,
        IWithdrawVerifier _withdrawVerifier,
        uint256 _denomination,
        uint256 _merkleTreeHeight
    ) Zyclone(_depositVerifier, _withdrawVerifier, _denomination, _merkleTreeHeight) {}

    function _processDeposit() internal override {
        require(msg.value == denomination, "Please send `Denomination` ETH along with transaction");
    }

    function _processWithdraw(address payable _recipient, address payable _relayer, uint256 _fee) internal override {
        (bool success,) = _recipient.call{value: (denomination - _fee)}("");
        require(success, "payment to _recipient did not go through");
        if (_fee > 0) {
            (success,) = _relayer.call{value: _fee}("");
            require(success, "payment to _relayer did not go through");
        }
    }
}
