// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidNetwork();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCALHOST_CHAIN_ID = 31337;
    NetworkConfig public activeNetworkConfig;
    address constant BURNER_WALLET=0xc196D24BacC51dDbD072C28c22aB0f85d37bcdB0;
    mapping(uint256 => NetworkConfig) public networkConfig; 

    constructor(){
        networkConfig[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
        networkConfig[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
    }
    function getConfig() public  returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
    function getConfigByChainId(uint256 chainId) public  returns (NetworkConfig memory) {
        if(chainId==LOCALHOST_CHAIN_ID){
            return getorCreateAnvilConfig();
        } else if(networkConfig[chainId].account != address(0)){
            return networkConfig[chainId];
        } else {
            revert HelperConfig__InvalidNetwork();
        }
    }
    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
            account:BURNER_WALLET   
        });
    }
    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            account:BURNER_WALLET
        });
    }
    function getorCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.account != address(0)) {
            return activeNetworkConfig;
        }
    }
}