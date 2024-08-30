//SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizeStablecoin} from "../../src/DecentralizeStablecoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract OpenInvariantTest is StdInvariant, Test {
    address public User1 = makeAddr("User1");
    address public User2 = makeAddr("User2");
    uint256 public constant ETH_MONEY = 10 ether;
    DSCEngine public dsce;
    DecentralizeStablecoin public dsc;
    HelperConfig public config;
    DeployDsc public deployer;
    Handler public handler;

    address public weth;
    address public wbtc;

    constructor() {
        vm.deal(User1, ETH_MONEY);
        vm.deal(User2, ETH_MONEY);
    }

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dsce, config) = deployer.run();
        (, , weth, wbtc, ) = config.activeNetworkConfig();
        console.log("address dsce", address(dsce));
        console.log("address dsc", address(dsc));
        // targetContract(address(dsce));
        handler = new Handler(dsc, dsce);
        targetContract(address(handler));
    }

    //any fuzz test we start with invariant_
    //statelfull fuzzing if one  test happen then other followed by other function test without retest
    function invariant_protocalthetotalsupply() public view {
        uint256 _totalDebt = dsc.totalSupply(); //how many tokens were creating

        uint256 _totalETHdepositvalue = ERC20Mock(weth).balanceOf(
            address(dsce)
        );
        uint256 _totalBTCdepositvalue = ERC20Mock(wbtc).balanceOf(
            address(dsce)
        );
        uint256 wethvalue = dsce.getUsdvalue(weth, _totalETHdepositvalue);
        uint256 wbtcvalue = dsce.getUsdvalue(wbtc, _totalBTCdepositvalue);
        console.log("wethvalue:", wethvalue);
        console.log("wbtcvalue", wbtcvalue);
        console.log("_totaldebt", _totalDebt);
        console.log("time_count", handler._timeCount());
        assert(wethvalue + wbtcvalue >= _totalDebt);
    }
}
