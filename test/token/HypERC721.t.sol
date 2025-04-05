// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.13;

/*          @@@@@@@@@@        
         @@@@@@@@@@@@       
        @@@@@@@@@@@@@@      
       @@@@@@@@@@@@@@@@     
      @@@@@@@   @@@@@@@@    
     @@@@@@@     @@@@@@@@   
    @@@@@@@       @@@@@@@@  
   @@@@@@@@@@@@@@@@@@@@@@@@
  @@@@@@@ AETHERIUM @@@@@@@@
 @@@@@@@             @@@@@@@@
@@@@@@@               @@@@@@@@*/

import "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

import {TestMailbox} from "../../contracts/test/TestMailbox.sol";
import {TestPostDispatchHook} from "../../contracts/test/TestPostDispatchHook.sol";
import {TypeCasts} from "../../contracts/libs/TypeCasts.sol";

import {ERC721Test} from "../../contracts/test/ERC721Test.sol";
import {TokenRouter} from "../../contracts/token/libs/TokenRouter.sol";
import {AetERC721} from "../../contracts/token/AetERC721.sol";
import {AetERC721Collateral} from "../../contracts/token/AetERC721Collateral.sol";
import {AetERC721URIStorage} from "../../contracts/token/extensions/AetERC721URIStorage.sol";
import {AetERC721URICollateral} from "../../contracts/token/extensions/AetERC721URICollateral.sol";

abstract contract AetTokenTest is Test, IERC721Receiver {
    using TypeCasts for address;

    uint256 internal constant INITIAL_SUPPLY = 10;
    string internal constant NAME = "Aetherium Hedgehogs";
    string internal constant SYMBOL = "HHH";

    address internal constant ALICE = address(0x1);
    address internal constant BOB = address(0x2);
    address internal constant PROXY_ADMIN = address(0x37);
    uint32 internal constant ORIGIN = 11;
    uint32 internal constant DESTINATION = 22;
    uint256 internal constant TRANSFER_ID = 0;
    string internal constant URI = "http://bit.ly/3reJLpx";

    ERC721Test internal localPrimaryToken =
        new ERC721Test(NAME, SYMBOL, INITIAL_SUPPLY * 2);
    ERC721Test internal remotePrimaryToken =
        new ERC721Test(NAME, SYMBOL, INITIAL_SUPPLY * 2);
    TestMailbox internal localMailbox;
    TestMailbox internal remoteMailbox;
    TokenRouter internal localToken;
    TokenRouter internal remoteToken;
    TestPostDispatchHook internal noopHook;

    event Dispatch(
        address indexed sender,
        uint32 indexed destination,
        bytes32 indexed recipient,
        bytes message
    );

    function setUp() public virtual {
        noopHook = new TestPostDispatchHook();

        localMailbox = new TestMailbox(ORIGIN);
        localMailbox.setDefaultHook(address(noopHook));
        localMailbox.setRequiredHook(address(noopHook));

        remoteMailbox = new TestMailbox(DESTINATION);

        remoteToken = new AetERC721Collateral(
            address(remotePrimaryToken),
            address(remoteMailbox)
        );
    }

    function _deployRemoteToken(bool isCollateral) internal {
        if (isCollateral) {
            AetERC721Collateral implementation = new AetERC721Collateral(
                address(remotePrimaryToken),
                address(remoteMailbox)
            );
            TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
                address(implementation),
                PROXY_ADMIN,
                abi.encodeWithSelector(
                    AetERC721Collateral.initialize.selector,
                    address(0),
                    address(0),
                    address(this)
                )
            );
            remoteToken = AetERC721Collateral(address(proxy));
            remotePrimaryToken.transferFrom(
                address(this),
                address(remoteToken),
                0
            ); // need for processing messages
        } else {
            AetERC721 implementation = new AetERC721(address(remoteMailbox));
            TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
                address(implementation),
                PROXY_ADMIN,
                abi.encodeWithSelector(
                    AetERC721.initialize.selector,
                    0,
                    NAME,
                    SYMBOL,
                    address(0),
                    address(0),
                    address(this)
                )
            );
            remoteToken = TokenRouter(address(proxy));
        }
        remoteToken.enrollRemoteRouter(
            ORIGIN,
            address(localToken).addressToBytes32()
        );
    }

    function _processTransfers(address _recipient, uint256 _tokenId) internal {
        vm.prank(address(remoteMailbox));
        remoteToken.handle(
            ORIGIN,
            address(localToken).addressToBytes32(),
            abi.encodePacked(_recipient.addressToBytes32(), _tokenId)
        );
    }

    function _performRemoteTransfer(
        uint256 _msgValue,
        uint256 _tokenId
    ) public {
        localToken.transferRemote{value: _msgValue}(
            DESTINATION,
            ALICE.addressToBytes32(),
            _tokenId
        );

        _processTransfers(BOB, _tokenId);
        assertEq(remoteToken.balanceOf(BOB), 1);
    }

    function testBenchmark_overheadGasUsage() public {
        vm.prank(address(localMailbox));

        uint256 gasBefore = gasleft();
        localToken.handle(
            DESTINATION,
            address(remoteToken).addressToBytes32(),
            abi.encodePacked(BOB.addressToBytes32(), INITIAL_SUPPLY + 1)
        );
        uint256 gasAfter = gasleft();
        console.log("Overhead gas usage: %d", gasBefore - gasAfter);
    }

    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract AetERC721Test is AetTokenTest {
    using TypeCasts for address;

    AetERC721 internal aet721;

    function setUp() public virtual override {
        super.setUp();

        AetERC721 implementation = new AetERC721(address(localMailbox));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            PROXY_ADMIN,
            abi.encodeWithSelector(
                AetERC721.initialize.selector,
                INITIAL_SUPPLY,
                NAME,
                SYMBOL,
                address(0),
                address(0),
                address(this)
            )
        );
        localToken = AetERC721(address(proxy));
        aet721 = AetERC721(address(proxy));

        aet721.enrollRemoteRouter(
            DESTINATION,
            address(remoteToken).addressToBytes32()
        );
    }

    function testInitialize_revert_ifAlreadyInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        aet721.initialize(
            INITIAL_SUPPLY,
            NAME,
            SYMBOL,
            address(0),
            address(0),
            address(this)
        );
    }

    function testTotalSupply() public {
        assertEq(aet721.balanceOf(address(this)), INITIAL_SUPPLY);
    }

    function testOwnerOf() public {
        assertEq(aet721.ownerOf(0), address(this));
    }

    function testLocalTransfer() public {
        aet721.transferFrom(address(this), ALICE, 0);
        assertEq(aet721.balanceOf(address(this)), INITIAL_SUPPLY - 1);
        assertEq(aet721.balanceOf(ALICE), 1);
    }

    function testLocalYTransfer_revert_invalidTokenId() public {
        vm.expectRevert("ERC721: invalid token ID");
        aet721.transferFrom(address(this), ALICE, INITIAL_SUPPLY);
    }

    function testRemoteTransfer(bool isCollateral) public {
        _deployRemoteToken(isCollateral);
        _performRemoteTransfer(25000, 0);
        assertEq(aet721.balanceOf(address(this)), INITIAL_SUPPLY - 1);
    }

    function testRemoteTransfer_revert_unowned() public {
        aet721.transferFrom(address(this), BOB, 1);

        _deployRemoteToken(false);
        vm.expectRevert("!owner");
        _performRemoteTransfer(25000, 1);
        assertEq(aet721.balanceOf(address(this)), INITIAL_SUPPLY - 1);
    }

    function testRemoteTransfer_revert_invalidTokenId() public {
        _deployRemoteToken(false);
        vm.expectRevert("ERC721: invalid token ID");
        _performRemoteTransfer(25000, INITIAL_SUPPLY);
        assertEq(aet721.balanceOf(address(this)), INITIAL_SUPPLY);
    }
}

contract MockAetERC721URIStorage is AetERC721URIStorage {
    constructor(address mailbox) AetERC721URIStorage(mailbox) {}

    function setTokenURI(uint256 tokenId, string memory uri) public {
        _setTokenURI(tokenId, uri);
    }
}

contract AetERC721URIStorageTest is AetTokenTest {
    using TypeCasts for address;

    MockAetERC721URIStorage internal aet721Storage;

    function setUp() public override {
        super.setUp();

        localToken = new MockAetERC721URIStorage(address(localMailbox));
        aet721Storage = MockAetERC721URIStorage(address(localToken));

        aet721Storage.initialize(
            INITIAL_SUPPLY,
            NAME,
            SYMBOL,
            address(0),
            address(0),
            address(this)
        );
        aet721Storage.setTokenURI(0, URI);
        aet721Storage.enrollRemoteRouter(
            DESTINATION,
            address(remoteToken).addressToBytes32()
        );
    }

    function testRemoteTransfers_revert_burned() public {
        _deployRemoteToken(false);
        _performRemoteTransfer(25000, 0);
        assertEq(aet721Storage.balanceOf(address(this)), INITIAL_SUPPLY - 1);

        vm.expectRevert("ERC721: invalid token ID");
        assertEq(aet721Storage.tokenURI(0), "");
    }
}

contract AetERC721CollateralTest is AetTokenTest {
    using TypeCasts for address;

    AetERC721Collateral internal aet721Collateral;

    function setUp() public override {
        super.setUp();

        AetERC721Collateral implementation = new AetERC721Collateral(
            address(localPrimaryToken),
            address(localMailbox)
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            PROXY_ADMIN,
            abi.encodeWithSelector(
                AetERC721Collateral.initialize.selector,
                address(0),
                address(0),
                address(this)
            )
        );
        localToken = AetERC721Collateral(address(proxy));
        aet721Collateral = AetERC721Collateral(address(localToken));

        aet721Collateral.enrollRemoteRouter(
            DESTINATION,
            address(remoteToken).addressToBytes32()
        );

        localPrimaryToken.transferFrom(
            address(this),
            address(aet721Collateral),
            INITIAL_SUPPLY + 1
        );
    }

    function testInitialize_revert_ifAlreadyInitialized() public {}

    function testRemoteTransfer(bool isCollateral) public {
        localPrimaryToken.approve(address(aet721Collateral), 0);
        _deployRemoteToken(isCollateral);
        _performRemoteTransfer(25000, 0);
        assertEq(
            aet721Collateral.balanceOf(address(this)),
            INITIAL_SUPPLY * 2 - 2
        );
    }

    function testRemoteTransfer_revert_unowned() public {
        localPrimaryToken.transferFrom(address(this), BOB, 1);

        _deployRemoteToken(false);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        _performRemoteTransfer(25000, 1);
        assertEq(
            aet721Collateral.balanceOf(address(this)),
            INITIAL_SUPPLY * 2 - 2
        );
    }

    function testRemoteTransfer_revert_invalidTokenId() public {
        _deployRemoteToken(false);
        vm.expectRevert("ERC721: invalid token ID");
        _performRemoteTransfer(25000, INITIAL_SUPPLY * 2);
        assertEq(
            aet721Collateral.balanceOf(address(this)),
            INITIAL_SUPPLY * 2 - 1
        );
    }
}

contract AetERC721CollateralURIStorageTest is AetTokenTest {
    using TypeCasts for address;

    AetERC721URICollateral internal aet721URICollateral;

    function setUp() public override {
        super.setUp();

        localToken = new AetERC721URICollateral(
            address(localPrimaryToken),
            address(localMailbox)
        );
        aet721URICollateral = AetERC721URICollateral(address(localToken));

        aet721URICollateral.enrollRemoteRouter(
            DESTINATION,
            address(remoteToken).addressToBytes32()
        );

        // localPrimaryToken.setTokenURI(0, URI);
        localPrimaryToken.transferFrom(
            address(this),
            address(aet721URICollateral),
            INITIAL_SUPPLY + 1
        );
        localPrimaryToken.ownerOf(0);
    }

    function testRemoteTransfers_revert_burned() public {
        _deployRemoteToken(false);
        localPrimaryToken.approve(address(aet721URICollateral), 0);

        bytes
            memory message = hex"03000000000000000b0000000000000000000000001d1499e622d69689cdf9004d05ec547d650ff21100000016000000000000000000000000a0cb889707d426a7a386870a03bc70d1b069759800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000544553542d424153452d55524930";
        vm.expectEmit(true, true, false, true);

        emit Dispatch(
            address(localToken),
            DESTINATION,
            address(remoteToken).addressToBytes32(),
            message
        );
        localToken.transferRemote{value: 25000}(
            DESTINATION,
            BOB.addressToBytes32(),
            TRANSFER_ID
        );

        _processTransfers(BOB, 0);
        assertEq(remoteToken.balanceOf(BOB), 1);
        assertEq(
            aet721URICollateral.balanceOf(address(this)),
            INITIAL_SUPPLY * 2 - 2
        );
    }
}
