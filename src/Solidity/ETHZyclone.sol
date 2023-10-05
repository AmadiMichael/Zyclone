// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.13;

import "./Zyclone.sol";

contract ETHZyclone is Zyclone {
    error NotEnoughValue();
    error PaymentUnsuccessful();
    error RelayerPaymentUnsuccessful();
    constructor(
        IDepositVerifier _depositVerifier,
        IWithdrawVerifier _withdrawVerifier,
        uint256 _denomination,
        uint256 _merkleTreeHeight
    ) Zyclone(_depositVerifier, _withdrawVerifier, _denomination, _merkleTreeHeight) {}

    function _processDeposit() internal override {
        if (msg.value != denomination) {
            revert NotEnoughValue();
        }
    }

    function _processWithdraw(address payable _recipient, address payable _relayer, uint256 _fee) internal override {
        (bool success,) = _recipient.call{value: (denomination - _fee)}("");
        if (!success) {
            revert PaymentUnsuccessful();
        }
        if (_fee > ZERO) {
            (success,) = _relayer.call{value: _fee}("");
            if (!success) {
                revert RelayerPaymentUnsuccessful();
            }
        }
    }
}
