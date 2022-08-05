//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

abstract contract DistributionHandlerBaseUpgradeable is ContextUpgradeable {
    event DistributionHandled(uint256 amount);

    address public distributor;

    modifier onlyDistributor() {
        require(_msgSender() == distributor, "Caller is not the distributor");
        _;
    }

    // solhint-disable-next-line func-name-mixedcase
    function __DistributionHandlerBaseUpgradeable_init(address distributor_)
        internal
        onlyInitializing
    {
        __Context_init();

        distributor = distributor_;
    }

    function _setDistributor(address _newDistributor) internal virtual {
        distributor = _newDistributor;
    }
}
