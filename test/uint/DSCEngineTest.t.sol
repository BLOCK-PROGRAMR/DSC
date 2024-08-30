//SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;
import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizeStablecoin} from "../../src/DecentralizeStablecoin.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DSCEngine public dsce;
    DecentralizeStablecoin public dsc;
    HelperConfig public config;
    DeployDsc public deploydsc;
    address public ethusdPricefeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public User1 = makeAddr("user1");
    address public User2 = makeAddr("user2");
    uint256 public constant ETH_MONEY = 10 ether;
    uint256 public constant MONEY_ETH = 100 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    constructor() {
        vm.deal(User1, MONEY_ETH);
        vm.deal(User2, ETH_MONEY);
    }

    function setUp() public {
        deploydsc = new DeployDsc();
        (dsc, dsce, config) = deploydsc.run();
        (ethusdPricefeed, btcUsdPriceFeed, weth, wbtc, ) = config
            .activeNetworkConfig();
    }

    //constructor tests
    address[] public _tokenaddress;
    address[] public _pricefeedaddress;

    function testRevertIfpricelengthnotequal() public {
        _tokenaddress.push(weth);
        _pricefeedaddress.push(ethusdPricefeed);
        _pricefeedaddress.push(btcUsdPriceFeed);
        vm.expectRevert(
            DSCEngine
                .DSCEngine__tokenAddressandpriceFeedAddrlengthNotEqual
                .selector
        );
        new DSCEngine(_tokenaddress, _pricefeedaddress, address(dsc));
    }

    //pricefeed tests
    function testgetUsdvalue() public view {
        uint256 ethamount = 10e18;
        uint256 expectedusd = ethamount * 2000;
        uint256 actualusd = dsce.getUsdvalue(weth, ethamount);
        console.log("expected and actual:", expectedusd, actualusd);
        assertEq(expectedusd, actualusd);
    }

    //deposit collateral test

    function testgetTokenAmountFromUsd() public view {
        uint256 givenUsd = 100 ether;
        // $2000/eth,$100 ?====>100*10e18*10e18/2000*10e10 =>100eth/2000=>
        uint256 assume = 0.05 ether;
        uint256 expected = dsce.getTokenAmountFromUsd(weth, givenUsd);
        assertEq(assume, expected);
    }

    function testERC20iszero() public {
        ERC20Mock _erc20mock = new ERC20Mock(
            "Scater",
            "SCTR",
            User1,
            ETH_MONEY
        );
        vm.startPrank(User1);
        vm.expectRevert(DSCEngine.DSCEngine__donotEnterZeroAddr.selector);
        dsce.depositCollateral(address(_erc20mock), AMOUNT_COLLATERAL);
        vm.stopPrank();
        // assertEq(address(_erc20mock), address(0));
    }

    function testPriceFeedAddress() public view {
        address[] memory _priceaddress = dsce.getAllpriceFeeds();
        // for (uint i = 0; i < _priceaddress.length; i++) {
        //     console.log("Address:", i, "->", _priceaddress[i]);
        // }
        assertEq(_priceaddress[0], ethusdPricefeed);
        assertEq(_priceaddress[1], btcUsdPriceFeed);
    }

    modifier DepositCollateral() {
        vm.startPrank(User1);

        // this token approve the permission to take some tokens
        ERC20Mock(weth).mint(User1, 50 ether);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testcanDepositCollateralandGetCollateral()
        public
        DepositCollateral
    {
        (uint256 _totalDscMint, uint256 _totalCollateralValue) = dsce
            .getAccountInfo(User1);

        uint256 expectDepositvalue = dsce.getTokenAmountFromUsd(
            weth,
            _totalCollateralValue / 2
        );
        console.log("totoalcollateralvalue2:", _totalCollateralValue / 2);
        console.log("totalDscMint:", _totalDscMint);
        console.log("Depositedvalue:", expectDepositvalue);

        uint256 expectedDscMint = 0;
        assertEq(expectDepositvalue, AMOUNT_COLLATERAL);
        assertEq(expectedDscMint, _totalDscMint);
    }

    function testgetcollateralBalanceofuser() public DepositCollateral {
        uint256 depositAmount = dsce.getCollateralBalanceOfUser(User1, weth);

        assertEq(depositAmount, AMOUNT_COLLATERAL);
    }

    function testmintdscandcheckhealthFactor() public {
        vm.startPrank(User1);
        // this token approve the permission to take some tokens
        ERC20Mock(weth).mint(User1, 50 ether);
        ERC20Mock(weth).approve(address(dsce), 1 ether);
        dsce.depositCollateral(weth, 1 ether);
        dsce.mintDSC(1 ether);
        uint256 depositAmount = dsce.getCollateralBalanceOfUser(User1, weth);
        console.log("deposittokenamount", depositAmount);
        uint256 mintAmount = dsce.getDscmintedvalue();
        console.log("MintedAmount:", mintAmount);
        vm.stopPrank();
    }

    function testdepositcollateralandmintdsc() public {
        vm.startPrank(User1);

        ERC20Mock(weth).mint(User1, 50 ether);
        ERC20Mock(weth).approve(address(dsce), 1 ether);
        dsce.depositCollateralAndMintDsc(weth, 1 ether, 1000);
        uint256 depositAmount = dsce.getCollateralBalanceOfUser(User1, weth);
        console.log("deposittokenamount", depositAmount);
        uint256 mintAmount = dsce.getDscmintedvalue();
        console.log("MintedAmount:", mintAmount);
        uint256 actualusd = dsce.getUsdvalue(weth, 1 ether);
        console.log("actucalusd", actualusd);
        vm.stopPrank();
    }
}
