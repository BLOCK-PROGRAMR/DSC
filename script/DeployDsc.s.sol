//SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;
import {Script} from "forge-std/Script.sol";
import {DecentralizeStablecoin} from "../src/DecentralizeStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDsc is Script {
    DecentralizeStablecoin public dsc;
    DSCEngine public dscEngine;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run()
        external
        returns (DecentralizeStablecoin, DSCEngine, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        vm.startBroadcast(deployerKey); //using privatekey to deploy
        dsc = new DecentralizeStablecoin(msg.sender);
        dscEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(dsc)
        );

        vm.stopBroadcast();
        vm.prank(msg.sender);
        dsc.transferOwnership(address(dscEngine));

        return (dsc, dscEngine, helperConfig);
    }
}
