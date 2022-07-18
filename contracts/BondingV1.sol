//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IEpochManager.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IDistributionHandler.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract BondingV1 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    IDistributionHandler
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    enum BondingMode {
        Normal,
        Community
    }

    struct BondOption {
        bool enabled;
        IERC20Upgradeable token;
        IPriceOracle oracle;
        uint8 discount; // .00 number
        uint256 bondingBalance;
    }

    struct Claim {
        uint256 amount;
        uint256 bondedAt;
    }

    uint8 public constant MIN_DISCOUNT = 1; // .00 number
    uint8 public constant MAX_DISCOUNT = 99; // .00 number

    IEpochManager public epochManager;

    IERC20Upgradeable public broToken;
    address public treasury;
    address public distributor;

    uint256 private minBroPayout;

    BondOption[] private bonds;
    uint256 private disabledBondOptions;

    mapping(address => Claim[]) private claims;

    BondingMode private mode;
    // Normal mode
    uint256 private vestingPeriod;
    // Community mode
    uint256 private unstakingPeriodEpochs;
    address private broStaking;

    modifier onlyDistributor() {
        require(msg.sender == distributor, "Caller is not the distributor");
        _;
    }

    function initialize(
        address epochManager_,
        address broToken_,
        address treasury_,
        address distributor_,
        uint256 minBroPayout_
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        epochManager = IEpochManager(epochManager_);
        broToken = IERC20Upgradeable(broToken_);
        treasury = treasury_;
        distributor = distributor_;
        minBroPayout = minBroPayout_;
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override {
        require(owner() == msg.sender, "Upgrade is not authorized");
    }

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
    }

    function enableBondOption(address _token) external onlyOwner {
        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);

        uint256 index = _getBondOptionIndex(bondingToken);

        require(!bonds[index].enabled, "Bonding option already enabled");
        bonds[index].enabled = true;
        disabledBondOptions--;
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
    }

    function removeBondOption(address _token) external onlyOwner {
        require(bonds.length > 1, "At least one bonding option should exist");

        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);

        uint256 index = _getBondOptionIndex(bondingToken);
        uint256 remainingBalance = bonds[index].bondingBalance;

        if (!bonds[index].enabled) {
            disabledBondOptions--;
        }

        bonds[index] = bonds[bonds.length - 1];
        bonds.pop();

        if (remainingBalance > 0) {
            broToken.safeTransfer(distributor, remainingBalance);
        }
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

    function setCommunityMode(
        address _broStaking,
        uint256 _unstakingPeriodEpochs
    ) external onlyOwner {
        mode = BondingMode.Community;
        broStaking = _broStaking;
        unstakingPeriodEpochs = _unstakingPeriodEpochs;
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
    }

    function bond(address _token, uint256 _amount) external {
        IERC20Upgradeable bondingToken = IERC20Upgradeable(_token);
        uint256 index = _getBondOptionIndex(bondingToken);
        require(bonds[index].enabled, "Bonding option is disabled");

        bondingToken.safeTransferFrom(msg.sender, treasury, _amount);
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
            Claim[] storage userClaims = claims[msg.sender];
            // solhint-disable-next-line not-rely-on-time
            userClaims.push(Claim(broPayout, block.timestamp));
            claims[msg.sender] = userClaims;
        } else if (mode == BondingMode.Community) {
            // TODO: add community bond lock in staking
        } else {
            revert("Unknown bonding mode");
        }
    }

    function claim() external {
        uint256 epoch = epochManager.getEpoch();
        Claim[] storage userClaims = claims[msg.sender];
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
        claims[msg.sender] = userClaims;
        broToken.safeTransfer(msg.sender, claimAmount);
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

        revert("Bonding option doesn't exists");
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
            a = unstakingPeriodEpochs;
            b = broStaking;
        }
    }

    function getDisabledBondOptionsCount() public view returns (uint256) {
        return disabledBondOptions;
    }
}
