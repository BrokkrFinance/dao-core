//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract Treasury is Ownable {
    using Address for address;
    using Address for address payable;
    using SafeERC20 for IERC20;

    mapping(IERC20 => bool) private whitelistedTokens;

    constructor(address[] memory whitelist_) {
        for (uint256 i = 0; i < whitelist_.length; i++) {
            whitelistedTokens[IERC20(whitelist_[i])] = true;
        }
    }

    modifier onlyWhitelistedToken(IERC20 _token) {
        require(whitelistedTokens[_token], "Token is not whitelisted");
        _;
    }

    receive() external payable {}

    function tokenTransfer(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external onlyOwner onlyWhitelistedToken(_token) {
        _tokenTransfer(_token, _to, _amount);
    }

    function tokenTransferWithCall(
        IERC20 _token,
        address _contract,
        uint256 _amount,
        bytes memory _data
    ) external onlyOwner onlyWhitelistedToken(_token) {
        _tokenTransfer(_token, _contract, _amount);
        _contract.functionCall(_data, "Failed to execute contracts method");
    }

    function nativeTransfer(address payable _to, uint256 _amount)
        external
        onlyOwner
    {
        _nativeTransfer(_to, _amount);
    }

    function nativeTransferWithCall(
        address payable _contract,
        uint256 _amount,
        bytes memory _data
    ) external onlyOwner {
        _nativeTransfer(_contract, _amount);
        _contract.functionCall(
            _data,
            "Failed to perform call to the contracts function"
        );
    }

    function _tokenTransfer(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) internal {
        require(
            _token.balanceOf(address(this)) >= _amount,
            "Insufficient funds"
        );
        _token.safeTransfer(_to, _amount);
    }

    function _nativeTransfer(address payable _to, uint256 _amount) internal {
        require(address(this).balance >= _amount, "Insufficient funds");
        _to.transfer(_amount);
    }

    function whitelistTokens(IERC20[] calldata _tokens) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            whitelistedTokens[_tokens[i]] = true;
        }
    }

    function removeWhitelisted(IERC20[] calldata _tokens) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            delete whitelistedTokens[_tokens[i]];
        }
    }

    function isTokenWhitelisted(IERC20 _token) public view returns (bool) {
        return whitelistedTokens[_token];
    }

    function balanceOf(IERC20 _token) public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function nativeBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
