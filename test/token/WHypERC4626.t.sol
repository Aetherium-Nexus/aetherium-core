// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MockMailbox} from "../../contracts/mock/MockMailbox.sol";
import {WAetERC4626} from "../../contracts/token/extensions/WAetERC4626.sol";
import {AetERC4626} from "../../contracts/token/extensions/AetERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAetERC4626 is AetERC4626 {
    constructor(address _mailbox) AetERC4626(18, 1, _mailbox, 2) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract WAetERC4626Test is Test {
    WAetERC4626 public wAetERC4626;
    MockAetERC4626 public underlyingToken;
    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        MockMailbox mailbox = new MockMailbox(1);
        underlyingToken = new MockAetERC4626(address(mailbox));
        wAetERC4626 = new WAetERC4626(
            underlyingToken,
            "Wrapped Rebasing Token",
            "WRT"
        );

        underlyingToken.mint(alice, 1000 * 10 ** 18);
        underlyingToken.mint(bob, 1000 * 10 ** 18);
    }

    function test_wrap() public {
        uint256 amount = 100 * 10 ** 18;

        vm.startPrank(alice);
        underlyingToken.approve(address(wAetERC4626), amount);
        uint256 wrappedAmount = wAetERC4626.wrap(amount);

        assertEq(wAetERC4626.balanceOf(alice), wrappedAmount);
        assertEq(underlyingToken.balanceOf(alice), 900 * 10 ** 18);
        vm.stopPrank();
    }

    function test_wrap_revertsWhen_zeroAmount() public {
        vm.startPrank(alice);
        underlyingToken.approve(address(wAetERC4626), 0);
        vm.expectRevert("WAetERC4626: wrap amount must be greater than 0");
        wAetERC4626.wrap(0);
        vm.stopPrank();
    }

    function test_unwrap() public {
        uint256 amount = 100 * 10 ** 18;

        vm.startPrank(alice);
        underlyingToken.approve(address(wAetERC4626), amount);
        uint256 wrappedAmount = wAetERC4626.wrap(amount);

        uint256 unwrappedAmount = wAetERC4626.unwrap(wrappedAmount);

        assertEq(wAetERC4626.balanceOf(alice), 0);
        assertEq(underlyingToken.balanceOf(alice), 1000 * 10 ** 18);
        assertEq(unwrappedAmount, amount);
        vm.stopPrank();
    }

    function test_unwrap_revertsWhen_zeroAmount() public {
        vm.startPrank(alice);
        vm.expectRevert("WAetERC4626: unwrap amount must be greater than 0");
        wAetERC4626.unwrap(0);
        vm.stopPrank();
    }

    function test_getWrappedAmount() public view {
        uint256 amount = 100 * 10 ** 18;
        uint256 wrappedAmount = wAetERC4626.getWrappedAmount(amount);

        assertEq(wrappedAmount, underlyingToken.assetsToShares(amount));
    }

    function test_getUnderlyingAmount() public view {
        uint256 amount = 100 * 10 ** 18;
        uint256 underlyingAmount = wAetERC4626.getUnderlyingAmount(amount);

        assertEq(underlyingAmount, underlyingToken.sharesToAssets(amount));
    }

    function test_wrappedPerUnderlying() public view {
        uint256 wrappedPerUnderlying = wAetERC4626.wrappedPerUnderlying();

        assertEq(
            wrappedPerUnderlying,
            underlyingToken.assetsToShares(1 * 10 ** underlyingToken.decimals())
        );
    }

    function test_underlyingPerWrapped() public view {
        uint256 underlyingPerWrapped = wAetERC4626.underlyingPerWrapped();

        assertEq(
            underlyingPerWrapped,
            underlyingToken.sharesToAssets(1 * 10 ** underlyingToken.decimals())
        );
    }

    function test_decimals() public view {
        uint8 decimals = wAetERC4626.decimals();

        assertEq(decimals, underlyingToken.decimals());
    }
}
