// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";

import {PackedUserOperation} from
    "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import {HelperConfig} from
    "script/HelperConfig.s.sol";

import {IEntryPoint} from
    "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

import {MessageHashUtils} from
    "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/*//////////////////////////////////////////////////////////////
                    SEND PACKED USER OP
//////////////////////////////////////////////////////////////*/

contract SendPackedUserOp is Script {

    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function run() external {}

    /*//////////////////////////////////////////////////////////////
                            PUBLIC
    //////////////////////////////////////////////////////////////*/

    function generatedSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory networkConfig,
        address account
    )
        public
        returns (PackedUserOperation memory)
    {
        /*//////////////////////////////////////////////////////////////
                    1. GENERATE UNSIGNED USER OP
        //////////////////////////////////////////////////////////////*/


                  uint256 nonce = IEntryPoint(networkConfig.entryPoint).getNonce(account, 0);

        PackedUserOperation memory unsignedUserOp =
            _generateUnsignedUserOperation(
                callData,
                account,
                nonce
            );

        /*//////////////////////////////////////////////////////////////
                        2. GENERATE USER OP HASH
        //////////////////////////////////////////////////////////////*/

        bytes32 userOpHash =
            IEntryPoint(networkConfig.entryPoint)
                .getUserOpHash(unsignedUserOp);

        bytes32 digest =
            userOpHash.toEthSignedMessageHash();

        /*//////////////////////////////////////////////////////////////
                            3. SIGN HASH
        //////////////////////////////////////////////////////////////*/
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 default_anvil_private_key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if(block.chainid==31337){
            ( v,  r,  s) = vm.sign(default_anvil_private_key, digest);
        } else {
            ( v,  r,  s) =
                vm.sign(networkConfig.account, digest);
        }

        /// signature format = r || s || v
        unsignedUserOp.signature =
            abi.encodePacked(r, s, v);

        return unsignedUserOp;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _generateUnsignedUserOperation(
    bytes memory callData,
    address sender,
    uint256 nonce
)
    internal
    pure
    returns (PackedUserOperation memory)
{
    uint128 verificationGasLimit = 300000;

    uint128 callGasLimit = 300000;

    uint256 maxPriorityFeePerGas = 1 gwei;

    uint256 maxFeePerGas = 2 gwei;

    return PackedUserOperation({
        sender: sender,
        nonce: nonce,
        initCode: hex"",
        callData: callData,

        accountGasLimits: bytes32(
            (uint256(verificationGasLimit) << 128)
                | uint256(callGasLimit)
        ),

        preVerificationGas: 50000,

        gasFees: bytes32(
            (uint256(maxPriorityFeePerGas) << 128)
                | uint256(maxFeePerGas)
        ),

        paymasterAndData: hex"",
        signature: hex""
    });
}
}