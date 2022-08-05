//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IEpochManager } from "./interfaces/IEpochManager.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { IDistributionHandler } from "./interfaces/IDistributionHandler.sol";
import { IStakingV1 } from "./interfaces/IStakingV1.sol";
import { IBondingV1 } from "./interfaces/IBondingV1.sol";
import { DistributionHandlerBaseUpgradeable } from "./base/DistributionHandlerBaseUpgradeable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract BondingV1 is
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IDistributionHandler,
    IBondingV1,
    DistributionHandlerBaseUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint8 public constant MIN_DISCOUNT = 1; // .00 number
    uint8 public constant MAX_DISCOUNT = 99; // .00 number

    IEpochManager public epochManager;
    IERC20Upgradeable public broToken;
    address public treasury;

    uint256 public minBroPayout;
    uint256 public disabledBondOptions;

    BondingMode public mode;
    // Normal mode
    uint256 public vestingPeriod;
    // Community mode
    uint256 public unstakingPeriod;
    IStakingV1 public broStaking;

    BondOption[] private bonds;
    mapping(address => Claim[]) private claims;

    function initialize(
        address epochManager_,
        address broToken_,
        address treasury_,
        address distributor_,
        uint256 minBroPayout_
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __DistributionHandlerBaseUpgradeable_init(distributor_);

        epochManager = IEpochManager(epochManager_);
        broToken = IERC20Upgradeable(broToken_);
        treasury = treasury_;
        minBroPayout = minBroPayout_;
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override onlyOwner {}

    function addBondOption(
        address _token,
        address _oracle,
        uint8 _discount
    ) external onlyOwner {
        require(
            _discount >= MIN_DISCOUNT && _discount <= MAX_DISCOUNT,
            "Wrong discount precision"
        );

        IERC20Upgradeable token = IERC20Upgradeable(_token);
        require(token != broToken, "Forbidden to bond against BRO Token");

        BondOption memory newOption = BondOption(
            true,
            token,
            IPriceOracle(_oracle),
            100 + _discount,
            0
        );
        for (uint256 i = 0; i < bonds.length; i++) {
            require(
                bonds[i].token != newOption.token,
                "Bond option already exists"
            );
        }

        bonds.push(newOption);
        emit BondOptionAdded(_token, _oracle, _discount);
    }

    function enableBondOption(address _token) external onlyOwner {
        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);

        uint256 index = _getBondOptionIndex(bondingToken);

        require(!bonds[index].enabled, "Bonding option already enabled");
        bonds[index].enabled = true;
        disabledBondOptions--;

        emit BondOptionEnabled(_token);
    }

    function disableBondOption(address _token) external onlyOwner {
        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);

        uint256 index = _getBondOptionIndex(bondingToken);

        require(bonds[index].enabled, "Bonding option already disabled");
        bonds[index].enabled = false;
        disabledBondOptions++;

        require(
            disabledBondOptions < bonds.length,
            "One or more bonding options should always be enabled"
        );
        emit BondOptionDisabled(_token);
    }

    function removeBondOption(address _token) external onlyOwner {
        require(
            bonds.length > 1,
            "At least one enabled bonding option should exist"
        );

        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);

        uint256 index = _getBondOptionIndex(bondingToken);
        uint256 remainingBalance = bonds[index].bondingBalance;

        if (!bonds[index].enabled) {
            disabledBondOptions--;
        }

        require(
            disabledBondOptions < bonds.length,
            "At least one enabled bonding option should exist"
        );

        bonds[index] = bonds[bonds.length - 1];
        bonds.pop();

        if (remainingBalance > 0) {
            broToken.safeTransfer(distributor, remainingBalance);
        }

        emit BondOptionRemoved(_token);
    }

    function updateBondDiscount(address _token, uint8 _newDiscount)
        external
        onlyOwner
    {
        require(
            _newDiscount >= MIN_DISCOUNT && _newDiscount <= MAX_DISCOUNT,
            "Wrong discount precision"
        );
        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);

        uint256 index = _getBondOptionIndex(bondingToken);
        bonds[index].discount = 100 + _newDiscount;
    }

    function setNormalMode(uint256 _vestingPeriod) external onlyOwner {
        mode = BondingMode.Normal;
        vestingPeriod = _vestingPeriod;
    }

    function setCommunityMode(address _broStaking, uint256 _unstakingPeriod)
        external
        onlyOwner
    {
        mode = BondingMode.Community;
        broStaking = IStakingV1(_broStaking);
        unstakingPeriod = _unstakingPeriod;
    }

    function setMinBroPayout(uint256 _newPayout) external onlyOwner {
        minBroPayout = _newPayout;
    }

    function handleDistribution(uint256 _amount) external onlyDistributor {
        uint256 activeBondOptions = bonds.length - disabledBondOptions;
        uint256 perBondDistribution = _amount / activeBondOptions;

        for (uint256 i = 0; i < bonds.length; i++) {
            if (bonds[i].enabled) {
                bonds[i].bondingBalance += perBondDistribution;
            }
        }

        emit DistributionHandled(_amount);
    }

    function bond(address _token, uint256 _amount) external whenNotPaused {
        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);
        uint256 index = _getBondOptionIndex(bondingToken);
        require(bonds[index].enabled, "Bonding option is disabled");

        bondingToken.safeTransferFrom(_msgSender(), treasury, _amount);
        bonds[index].oracle.updatePrice();

        uint256 broPayout = _swap(index, _token, _amount);
        require(
            broPayout >= minBroPayout,
            "Bond payout is less then min bro payout"
        );
        require(
            bonds[index].bondingBalance >= broPayout,
            "Not enough balance for payout"
        );

        bonds[index].bondingBalance -= broPayout;

        if (mode == BondingMode.Normal) {
            Claim[] storage userClaims = claims[_msgSender()];
            // solhint-disable-next-line not-rely-on-time
            userClaims.push(Claim(broPayout, block.timestamp));
            claims[_msgSender()] = userClaims;
        } else {
            broToken.safeApprove(address(broStaking), broPayout);
            broStaking.communityBondStake(
                _msgSender(),
                broPayout,
                unstakingPeriod
            );
        }

        emit BondPerformed(_token, _amount);
    }

    function claim() external whenNotPaused {
        uint256 epoch = epochManager.getEpoch();
        Claim[] storage userClaims = claims[_msgSender()];
        uint256 claimAmount = 0;

        uint256 i = 0;
        while (i < userClaims.length) {
            uint256 expiresAt = userClaims[i].bondedAt +
                (epoch * vestingPeriod);
            // solhint-disable-next-line not-rely-on-time
            if (expiresAt <= block.timestamp) {
                claimAmount += userClaims[i].amount;
                userClaims[i] = userClaims[userClaims.length - 1];
                userClaims.pop();
            } else {
                i++;
            }
        }

        require(claimAmount > 0, "Nothing to claim");
        claims[_msgSender()] = userClaims;
        broToken.safeTransfer(_msgSender(), claimAmount);

        emit BondClaimed(_msgSender(), claimAmount);
    }

    function _getBondOptionIndex(IERC20Upgradeable _token)
        private
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < bonds.length; i++) {
            if (bonds[i].token == _token) {
                return i;
            }
        }

        revert BondingOptionNotFound(_token);
    }

    function _swap(
        uint256 _index,
        address _token,
        uint256 _amount
    ) private view returns (uint256) {
        uint256 broAmount = bonds[_index].oracle.consult(_token, _amount);
        uint256 broPayout = (broAmount * bonds[_index].discount) / 100;
        return broPayout;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function supportsDistributions() public pure returns (bool) {
        return true;
    }

    function approveTo() public view returns (address) {
        return treasury;
    }

    function getClaims(address _account) public view returns (Claim[] memory) {
        return claims[_account];
    }

    function getBondOptions() public view returns (BondOption[] memory) {
        return bonds;
    }

    function getBondOptionByIndex(uint256 _index)
        public
        view
        returns (BondOption memory)
    {
        return bonds[_index];
    }

    function simulateBond(address _token, uint256 _amount)
        public
        view
        returns (uint256)
    {
        return
            _swap(
                _getBondOptionIndex(IERC20Upgradeable(_token)),
                _token,
                _amount
            );
    }

    function getBondingMode() public view returns (BondingMode) {
        return mode;
    }

    function getModeConfig() public view returns (uint256 a, address b) {
        if (mode == BondingMode.Normal) {
            a = vestingPeriod;
        }
        if (mode == BondingMode.Community) {
            a = unstakingPeriod;
            b = address(broStaking);
        }
    }
}
