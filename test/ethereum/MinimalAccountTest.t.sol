// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimial.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp,PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;
    HelperConfig helperConfig;
    MinimalAccount account;
    ERC20Mock usdc;
    address randomuser=makeAddr("randomuser");
    uint256 constant amount=1e18;
    SendPackedUserOp sendPackedUserOp;
    function setUp() public {
       DeployMinimal deployer = new DeployMinimal();
       (helperConfig, account) = deployer.deployMinimalAccount();
       usdc=new ERC20Mock();
       sendPackedUserOp = new SendPackedUserOp();
    }
    
    function testOwnerCanExecute() public {
        // Arrange
        assertEq(usdc.balanceOf(address(account)), 0);
        address destination=address(usdc);
        uint256 value=0;
        bytes memory data=abi.encodeWithSelector(ERC20Mock.mint.selector,address(account),amount);


        // ACT
        vm.prank(account.owner());
        account.execute(destination, value, data);

        // Assert
        assertEq(usdc.balanceOf(address(account)), amount);
    }
    function testNotOwnerCannotExecute() public {
        // Arrange
        address destination=address(usdc);
        uint256 value=0;
        bytes memory data=abi.encodeWithSelector(ERC20Mock.mint.selector,address(account),amount);

        // ACT
        vm.prank(address(0x123));
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromOwner.selector);
        account.execute(destination, value, data);
    }
    function testValidationOfUserOps() public{
        assertEq(usdc.balanceOf(address(account)), 0);
        address destination=address(usdc);
        uint256 value=0;
        bytes memory data=abi.encodeWithSelector(ERC20Mock.mint.selector,address(account),amount);
        bytes memory callData=abi.encodeWithSelector(MinimalAccount.execute.selector,destination, value, data);
       
        
        PackedUserOperation memory signedUserOp=sendPackedUserOp.generatedSignedUserOperation(callData,helperConfig.getConfig(),address(account));

        bytes32 userOpHash=IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(signedUserOp);
        // ACT
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationResult=account.validateUserOp(signedUserOp, userOpHash, 0);
        assertEq(validationResult, 0);
    }
    function testRecoverSignedOp() public {
        // Arrange
        address destination=address(usdc);
        uint256 value=0;
        bytes memory data=abi.encodeWithSelector(ERC20Mock.mint.selector,address(account),amount);
        bytes memory callData=abi.encodeWithSelector(MinimalAccount.execute.selector,destination, value, data);
       
        
        PackedUserOperation memory signedUserOp=sendPackedUserOp.generatedSignedUserOperation(callData,helperConfig.getConfig(),address(account));

        bytes32 userOpHash=IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(signedUserOp);
        // ACT
        address recoveredSigner=ECDSA.recover(userOpHash.toEthSignedMessageHash(), signedUserOp.signature);

        assertEq(recoveredSigner, account.owner());

    }
   function testEntryPointExecuteCommand() public {
    assertEq(usdc.balanceOf(address(account)), 0);
    address destination = address(usdc);
    uint256 value = 0;
    bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(account), amount);
    bytes memory callData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, data);

    PackedUserOperation memory signedUserOp = sendPackedUserOp.generatedSignedUserOperation(
        callData, helperConfig.getConfig(), address(account)
    );

    vm.deal(address(account), amount);
    PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    ops[0] = signedUserOp;

    // ✅ Cache BEFORE vm.prank — no external calls after prank
    address entryPoint = helperConfig.getConfig().entryPoint;

    vm.prank(randomuser);
    IEntryPoint(entryPoint).handleOps(ops, payable(randomuser)); // ← immediately next call

    assertEq(usdc.balanceOf(address(account)), amount);
}
}