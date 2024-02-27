//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IEpochManager } from "./interfaces/IEpochManager.sol";
import { IDistributionHandler } from "./interfaces/IDistributionHandler.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenDistributor is Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct Distribution {
        IDistributionHandler handler;
        uint256 amount;
    }

    IERC20 public immutable broToken;
    IEpochManager public immutable epochManager;

    uint256 private lastDistribution;
    uint256 private totalDistributionAmountPerEpoch;
    Distribution[] private distributions;

    event DistributionTriggered(uint256 distributionAmount);
    event DistributionAdded(address indexed to, uint256 amount);
    event DistributionRemoved(address indexed to);
    event DistributionAmountUpdated(
        address indexed to,
        uint256 oldAmount,
        uint256 newAmount
    );

    constructor(
        address token_,
        address epochManager_,
        uint256 distributionStartTimestamp_
    ) Ownable(msg.sender) {
        broToken = IERC20(token_);
        epochManager = IEpochManager(epochManager_);
        lastDistribution = distributionStartTimestamp_;
    }

    modifier withValidIndex(uint256 _index) {
        require(_index < distributions.length, "Out of bounds.");
        _;
    }

    function distribute() external whenNotPaused {
        require(distributions.length > 0, "Distributions is not registered.");

        (uint256 passedEpochs, uint256 distributedAt) = calculatePassedEpochs();
        require(passedEpochs > 0, "Nothing to distribute.");

        uint256 distributionAmount = totalDistributionAmountPerEpoch *
            passedEpochs;
        require(
            broToken.balanceOf(address(this)) >= distributionAmount,
            "Not enough tokens for distribution."
        );

        for (uint256 i = 0; i < distributions.length; i++) {
            Distribution memory d = distributions[i];

            uint256 amount = passedEpochs * d.amount;
            broToken.safeTransfer(address(d.handler), amount);
            d.handler.handleDistribution(amount);
        }

        lastDistribution = distributedAt;
        emit DistributionTriggered(distributionAmount);
    }

    function addDistribution(address _to, uint256 _amount) external onlyOwner {
        Distribution memory distribution = Distribution(
            IDistributionHandler(_to),
            _amount
        );

        require(
            distribution.handler.supportsDistributions(),
            "Provided address doesn't support distributions."
        );

        for (uint256 i = 0; i < distributions.length; i++) {
            require(
                distributions[i].handler != distribution.handler,
                "Distribution already exists."
            );
        }

        totalDistributionAmountPerEpoch += _amount;
        distributions.push(distribution);

        emit DistributionAdded(_to, _amount);
    }

    function removeDistribution(uint256 _index)
        external
        onlyOwner
        withValidIndex(_index)
    {
        address to = address(distributions[_index].handler);

        totalDistributionAmountPerEpoch -= distributions[_index].amount;
        distributions[_index] = distributions[distributions.length - 1];
        distributions.pop();

        emit DistributionRemoved(to);
    }

    function updateDistributionAmount(uint256 _index, uint256 _amount)
        external
        onlyOwner
        withValidIndex(_index)
    {
        uint256 oldAmount = distributions[_index].amount;
        totalDistributionAmountPerEpoch -= oldAmount;
        distributions[_index].amount = _amount;
        totalDistributionAmountPerEpoch += _amount;

        emit DistributionAmountUpdated(
            address(distributions[_index].handler),
            oldAmount,
            _amount
        );
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function totalDistributions() public view returns (uint256) {
        return distributions.length;
    }

    function perEpochDistributionAmount() public view returns (uint256) {
        return totalDistributionAmountPerEpoch;
    }

    function distributionByIndex(uint256 _index)
        public
        view
        returns (Distribution memory)
    {
        return distributions[_index];
    }

    function isReadyForDistribution() public view returns (bool) {
        (uint256 passedEpochs, ) = calculatePassedEpochs();
        return passedEpochs > 0 ? true : false;
    }

    function calculatePassedEpochs()
        private
        view
        returns (uint256 passedEpochs, uint256 distributedAt)
    {
        uint256 epoch = epochManager.getEpoch();
        // solhint-disable-next-line not-rely-on-time
        uint256 timespanSinceLastDistribution = block.timestamp -
            lastDistribution;

        passedEpochs = timespanSinceLastDistribution / epoch;
        distributedAt = lastDistribution + (epoch * passedEpochs);
    }
}
