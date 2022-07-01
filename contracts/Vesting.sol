//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vesting is Ownable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 endTime;
        uint256 broAmount;
    }

    struct VestingInfo {
        VestingSchedule[] schedules;
        uint256 lastClaim;
    }

    IERC20 public immutable broToken;

    mapping(address => VestingInfo) private vestingInfos;

    constructor(address token_) {
        broToken = IERC20(token_);
    }

    function claim() external {
        VestingInfo storage info = vestingInfos[msg.sender];
        require(info.schedules.length > 0, "No vesting schedules was found");

        uint256 claimAmount = computeClaimAmount(info);
        require(claimAmount > 0, "Nothing to claim");

        // solhint-disable-next-line not-rely-on-time
        info.lastClaim = block.timestamp;
        vestingInfos[msg.sender] = info;

        broToken.safeTransfer(msg.sender, claimAmount);
    }

    function computeClaimAmount(VestingInfo memory _info)
        internal
        view
        returns (uint256 claimAmount)
    {
        for (uint256 i = 0; i < _info.schedules.length; i++) {
            if (
                // solhint-disable-next-line not-rely-on-time
                block.timestamp > _info.schedules[i].endTime &&
                _info.lastClaim < _info.schedules[i].endTime
            ) {
                claimAmount += _info.schedules[i].broAmount;
            }
        }
    }

    function registerSchedules(
        address[] calldata _accounts,
        VestingSchedule[][] calldata _schedules
    ) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            VestingInfo storage info = vestingInfos[_accounts[i]];

            VestingSchedule[] memory newSchedules = _schedules[i];
            for (uint256 j = 0; j < newSchedules.length; j++) {
                info.schedules.push(newSchedules[j]);
            }

            vestingInfos[_accounts[i]] = info;
        }
    }

    function removeAccount(address _account) external onlyOwner {
        delete vestingInfos[_account];
    }

    function vestingInfo(address _account)
        public
        view
        returns (VestingInfo memory)
    {
        return vestingInfos[_account];
    }

    function claimableAmount(address _account) public view returns (uint256) {
        return computeClaimAmount(vestingInfos[_account]);
    }
}
