// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {TypeCasts} from "./TypeCasts.sol";

struct Checkpoint {
    uint32 origin;
    bytes32 merkleTree;
    bytes32 root;
    uint32 index;
    bytes32 messageId;
}

library CheckpointLib {
    using TypeCasts for bytes32;

    /**
     * @notice Returns the digest validators are expected to sign when signing checkpoints.
     * @param _origin The origin domain of the checkpoint.
     * @param _merkleTreeHook The address of the origin merkle tree hook as bytes32.
     * @param _checkpointRoot The root of the checkpoint.
     * @param _checkpointIndex The index of the checkpoint.
     * @param _messageId The message ID of the checkpoint.
     * @dev Message ID must match leaf content of checkpoint root at index.
     * @return The digest of the checkpoint.
     */
    function digest(
        uint32 _origin,
        bytes32 _merkleTreeHook,
        bytes32 _checkpointRoot,
        uint32 _checkpointIndex,
        bytes32 _messageId
    ) internal pure returns (bytes32) {
        bytes32 _domainHash = domainHash(_origin, _merkleTreeHook);
        return
            ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        _domainHash,
                        _checkpointRoot,
                        _checkpointIndex,
                        _messageId
                    )
                )
            );
    }

    /**
     * @notice Returns the digest validators are expected to sign when signing checkpoints.
     * @param checkpoint The checkpoint (struct) to hash.
     * @return The digest of the checkpoint.
     */
    function digest(
        Checkpoint memory checkpoint
    ) internal pure returns (bytes32) {
        return
            digest(
                checkpoint.origin,
                checkpoint.merkleTree,
                checkpoint.root,
                checkpoint.index,
                checkpoint.messageId
            );
    }

    function merkleTreeAddress(
        Checkpoint calldata checkpoint
    ) internal pure returns (address) {
        return checkpoint.merkleTree.bytes32ToAddress();
    }

    /**
     * @notice Returns the domain hash that validators are expected to use
     * when signing checkpoints.
     * @param _origin The origin domain of the checkpoint.
     * @param _merkleTreeHook The address of the origin merkle tree as bytes32.
     * @return The domain hash.
     */
    function domainHash(
        uint32 _origin,
        bytes32 _merkleTreeHook
    ) internal pure returns (bytes32) {
        // Including the origin merkle tree address in the signature allows the slashing
        // protocol to enroll multiple trees. Otherwise, a valid signature for
        // tree A would be indistinguishable from a fraudulent signature for tree B.
        // The slashing protocol should slash if validators sign attestations for
        // anything other than a whitelisted tree.
        return
            keccak256(abi.encodePacked(_origin, _merkleTreeHook, "AETHERIUM"));
    }
}
