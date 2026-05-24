// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimial.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
contract MinimalAccountTest is Test {
    HelperConfig helperConfig;
    MinimalAccount account;
    ERC20Mock usdc;
    uint256 constant amount=1e18;
    function setUp() public {
       DeployMinimal deployer = new DeployMinimal();
       (helperConfig, account) = deployer.deployMinimalAccount();
       usdc=new ERC20Mock();
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
}