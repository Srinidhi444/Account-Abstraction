// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {Script} from "forge-std/Script.sol";

import {MinimalAccount} from
    "src/ethereum/MinimalAccount.sol";

import {HelperConfig} from
    "script/HelperConfig.s.sol";

/*//////////////////////////////////////////////////////////////
                        DEPLOY MINIMAL
//////////////////////////////////////////////////////////////*/

contract DeployMinimal is Script {

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function run() external {
        deployMinimalAccount();
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC
    //////////////////////////////////////////////////////////////*/

    function deployMinimalAccount()
        public
        returns (
            HelperConfig helperConfig,
            MinimalAccount account
        )
    {
        /// get network configuration
        helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory networkConfig =
            helperConfig.getConfig();

        /// start broadcasting transactions
        vm.startBroadcast(networkConfig.account);

        /// deploy minimal account
        account = new MinimalAccount(
            networkConfig.entryPoint
        );

        /// transfer ownership to deployer
        account.transferOwnership(
            networkConfig.account
        );

        vm.stopBroadcast();

        return (helperConfig, account);
    }
}