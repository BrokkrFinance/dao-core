//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IEpochManager.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IDistributionHandler.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BondingV1 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    IDistributionHandler
{
    using SafeERC20 for IERC20;

    enum BondingMode {
        Normal,
        Community
    }

    struct BondOption {
        bool enabled;
        IERC20 token;
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

    IERC20 public broToken;
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
    uint256 private epochsLocked;
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
        broToken = IERC20(broToken_);
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

        BondOption memory newOption = BondOption(
            true,
            IERC20(_token),
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

    function setNormalMode(uint256 _vestingPeriod) external onlyOwner {
        mode = BondingMode.Normal;
        vestingPeriod = _vestingPeriod;
    }

    function setCommunityMode(address _broStaking, uint256 _epochsLocked)
        external
        onlyOwner
    {
        mode = BondingMode.Community;
        broStaking = _broStaking;
        epochsLocked = _epochsLocked;
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

    function _getBondOptionIndex(IERC20 _token)
        private
        view
        returns (uint256 index)
    {
        bool exists;
        for (uint256 i = 0; i < bonds.length; i++) {
            if (bonds[i].token == _token) {
                exists = true;
                index = i;
            }
        }

        require(exists, "Bonding option doesn't exists");
    }

    function _swap(
        uint256 _index,
        address _token,
        uint256 _amount
    ) private view returns (uint256) {
        //TODO: double check price calc
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

    function simulateBond(address _token, uint256 _amount)
        public
        view
        returns (uint256)
    {
        return _swap(_getBondOptionIndex(IERC20(_token)), _token, _amount);
    }
}
