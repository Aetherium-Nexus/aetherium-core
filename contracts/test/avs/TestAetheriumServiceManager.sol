// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import {Enrollment, EnrollmentStatus, EnumerableMapEnrollment} from "../../libs/EnumerableMapEnrollment.sol";
import {AetheriumServiceManager} from "../../avs/AetheriumServiceManager.sol";

contract TestAetheriumServiceManager is AetheriumServiceManager {
    using EnumerableMapEnrollment for EnumerableMapEnrollment.AddressToEnrollmentMap;

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _paymentCoordinator,
        address _delegationManager
    )
        AetheriumServiceManager(
            _avsDirectory,
            _stakeRegistry,
            _paymentCoordinator,
            _delegationManager
        )
    {}

    function mockSetUnenrolled(address operator, address challenger) external {
        enrolledChallengers[operator].set(
            address(challenger),
            Enrollment(EnrollmentStatus.UNENROLLED, 0)
        );
    }
}
