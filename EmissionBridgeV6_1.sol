// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  EmissionBridge — V6.1 MAINNET
 * @author Architect — BLOCKCHAIN ARCHITECT
 * @notice Deployed: 0xa2e18bc91279922ad7536a487b47d74b4f108e3e
 *
 * MISSION 1: Hold monthly emission tokens (1,388,889 TRUST per release)
 *            Owner sends to market manually (once per 30 days)
 * MISSION 2: Accumulate tokens during panic buyback
 *
 * FLOW: monthlyRelease() → this bridge → sendToMarket(holder)
 * NOTE: Tax IS applied when sending FROM this bridge to non-exempt addresses
 *       Wallet limit IS enforced on recipient (FIX v6.1)
 */
contract EmissionBridgeV6Mainnet is Ownable {

    IERC20 public trustToken;

    event TokensSentToMarket(address indexed to, uint256 amount, uint256 ts);
    event BatchSent(uint256 recipients, uint256 totalSent, uint256 ts);

    constructor(address _trustToken) Ownable(msg.sender) {
        require(_trustToken != address(0), "Zero: trustToken");
        trustToken = IERC20(_trustToken);
    }

    function sendToMarket(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Zero address");
        require(_amount > 0, "Zero amount");
        require(trustToken.balanceOf(address(this)) >= _amount, "Insufficient balance");
        require(trustToken.transfer(_to, _amount), "Transfer failed");
        emit TokensSentToMarket(_to, _amount, block.timestamp);
    }

    function batchSendEqual(address[] calldata _to, uint256 _amount) external onlyOwner {
        require(_to.length > 0, "Empty list");
        require(_to.length <= 100, "Max 100 recipients");
        require(_amount > 0, "Zero amount");
        uint256 total = _amount * _to.length;
        require(trustToken.balanceOf(address(this)) >= total, "Insufficient balance");
        for (uint256 i = 0; i < _to.length;) {
            require(_to[i] != address(0), "Zero recipient");
            require(trustToken.transfer(_to[i], _amount), "Transfer failed");
            unchecked { i++; }
        }
        emit BatchSent(_to.length, total, block.timestamp);
    }

    function batchSend(address[] calldata _to, uint256[] calldata _amounts) external onlyOwner {
        require(_to.length > 0, "Empty list");
        require(_to.length <= 100, "Max 100 recipients");
        require(_to.length == _amounts.length, "Length mismatch");
        uint256 total;
        for (uint256 i = 0; i < _amounts.length;) { unchecked { total += _amounts[i]; i++; } }
        require(trustToken.balanceOf(address(this)) >= total, "Insufficient balance");
        for (uint256 i = 0; i < _to.length;) {
            require(_to[i] != address(0), "Zero recipient");
            require(trustToken.transfer(_to[i], _amounts[i]), "Transfer failed");
            unchecked { i++; }
        }
        emit BatchSent(_to.length, total, block.timestamp);
    }

    function bridgeBalance() external view returns (uint256) { return trustToken.balanceOf(address(this)); }

    function version() external pure returns (string memory) {
        return "EmissionBridge V6.1 MAINNET batch100 antiwhale-fix";
    }
}
