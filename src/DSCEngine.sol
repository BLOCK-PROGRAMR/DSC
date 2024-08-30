//SPDX-License-Identifier:MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations//means enums and structs
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
pragma solidity ^0.8.22;

import {DecentralizeStablecoin} from "./DecentralizeStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "../src/lib/OracleLib.sol";

contract DSCEngine is ReentrancyGuard {
    ///ERRORS://
    error DSCEngineNotimprovedHealthFactor();
    error DSCEngineOverCollateralized();
    error DSCEngine_MintfunctionisFailed();
    error DSCEngine_HealthFactorisBroken();
    error DSCEngine__tokenAddressandpriceFeedAddrlengthNotEqual();
    error DSCEngine__amountmustbeGreaterthanZero();
    error DSCEngine__donotEnterZeroAddr();
    error DSCEngine_transferailed();

    //types
    using OracleLib for AggregatorV3Interface;
    // STATE VARIABLES//
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //This means you need to be 200% over-collateralized
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;
    mapping(address user => uint256 amount) private s_DSCMinted;
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenaddr => uint256 amount))
        private s_collateralDeposited;
    DecentralizeStablecoin private immutable i_dsc;
    address[] private s_collateralTokens;
    address[] private Pricefeeds;
    //EVENTS//

    event collateral_Deposit(address indexed, address indexed, uint256 indexed);
    event CollateralReedemed(
        address indexed from,
        address indexed to,
        address indexed tokenCollateral,
        uint256 collateralAmount
    );
    //MODIFIERS://

    modifier morethanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__amountmustbeGreaterthanZero();
        }
        _;
    }

    modifier hasAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__donotEnterZeroAddr();
        }
        _;
    }

    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddress,
        address dscAdrr
    ) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__tokenAddressandpriceFeedAddrlengthNotEqual();
        }

        for (uint256 i = 0; i < tokenAddress.length; i++) {
            Pricefeeds.push(priceFeedAddress[i]);
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizeStablecoin(dscAdrr);
    }

    //external functions

    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    function redeemCollateralForDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    )
        external
        nonReentrant
        morethanZero(amountCollateral)
        hasAllowedToken(tokenCollateralAddress)
    {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(
            tokenCollateralAddress,
            amountCollateral,
            msg.sender,
            msg.sender
        );
        _revertIfhealthFactorisbroken(msg.sender);
    }

    function redeemCollateral(
        address tokencollateraddr,
        uint256 collateralamount
    )
        external
        morethanZero(collateralamount)
        hasAllowedToken(tokencollateraddr)
    {
        _redeemCollateral(
            tokencollateraddr,
            collateralamount,
            msg.sender,
            msg.sender
        );
    }

    function burnDsc(uint256 _amount) external morethanZero(_amount) {
        _burnDsc(_amount, msg.sender, msg.sender);
        _revertIfhealthFactorisbroken(msg.sender);
    }

    function liquidator(
        address collateraladdress,
        address user,
        uint256 debtToCover
    )
        external
        morethanZero(debtToCover)
        nonReentrant
        hasAllowedToken(collateraladdress)
    {
        uint256 startedusingHealthFactor = _healthfactor(user);
        if (startedusingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngineOverCollateralized();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            collateraladdress,
            debtToCover
        );
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        _redeemCollateral(
            collateraladdress,
            tokenAmountFromDebtCovered + bonusCollateral,
            user,
            msg.sender
        );
        _burnDsc(debtToCover, user, msg.sender);
        uint256 endHealthFacotor = _healthfactor(user);
        if (endHealthFacotor <= startedusingHealthFactor) {
            revert DSCEngineNotimprovedHealthFactor();
        }
        _revertIfhealthFactorisbroken(msg.sender);
    }

    //private functions and internal functions

    function _burnDsc(
        uint256 amountDscToBurn,
        address onBehalfOf,
        address dscFrom
    ) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;

        bool success = i_dsc.transferFrom(
            dscFrom,
            address(this),
            amountDscToBurn
        );
        // This conditional is hypothetically unreachable
        if (!success) {
            revert DSCEngine_transferailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(
        address collateralAddr,
        uint256 _collateralamount,
        address from,
        address to
    ) private morethanZero(_collateralamount) hasAllowedToken(collateralAddr) {
        s_collateralDeposited[from][collateralAddr] -= _collateralamount;
        emit CollateralReedemed(
            msg.sender,
            msg.sender,
            collateralAddr,
            _collateralamount
        );
        bool send = IERC20(collateralAddr).transfer(to, _collateralamount);
        if (!send) {
            revert DSCEngine_transferailed();
        }
    }

    function _healthfactor(address user) private view returns (uint256) {
        (
            uint256 _totalDSCvalue,
            uint256 _totalCollateralvalue
        ) = getAccountInformation(user);
        return _calculatehealthfactor(_totalDSCvalue, _totalCollateralvalue);
    }

    function getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 _totalDSCmint, uint256 _totalcollateralmint)
    {
        _totalDSCmint = s_DSCMinted[user];
        _totalcollateralmint = getAccountCollateralValue(user);
    }

    function _calculatehealthfactor(
        uint256 _totalDSCvalue,
        uint256 _totalcollateralvalue
    ) internal pure returns (uint256) {
        if (_totalDSCvalue == 0) {
            return type(uint256).max;
        }
        uint256 _calculationThreshold = ((_totalcollateralvalue) *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 _combineThreshold = (_calculationThreshold * PRECISION) /
            _totalDSCvalue;
        return _combineThreshold;
    }

    function _revertIfhealthFactorisbroken(address user) internal view {
        uint256 _amount = _healthfactor(user);
        if (_amount < MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorisBroken();
        }
    }

    ///////////////
    //pubic-functions//
    ///////////////

    function getUsdvalue(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_token]
        );
        (, int256 _money, , , ) = priceFeed.staleChecklatestprice();
        uint256 __money = uint256(_money) * ADDITIONAL_FEED_PRECISION; //1e10*_money
        return (__money * _amount) / PRECISION;
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdvalue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function depositCollateral(
        address _tokencollateraladdr,
        uint256 _tokenAmount
    )
        public
        hasAllowedToken(_tokencollateraladdr)
        nonReentrant
        morethanZero(_tokenAmount)
    {
        s_collateralTokens.push(_tokencollateraladdr);
        s_collateralDeposited[msg.sender][_tokencollateraladdr] = _tokenAmount;
        bool success = IERC20(_tokencollateraladdr).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
        if (!success) {
            revert DSCEngine_transferailed();
        }
        emit collateral_Deposit(msg.sender, _tokencollateraladdr, _tokenAmount);
    }

    /**
     *
     * we  can _amountdscmint you mint but you can the match the collateral value means satisfy the above condition
     * $5000-->5000*50/100=2500
     * mintdscamount=1000 then 2500/1000=2.5 satisty but we can mint 3000 it will not satisy
     */
    function mintDSC(
        uint256 _amountdscmint
    ) public morethanZero(_amountdscmint) nonReentrant {
        s_DSCMinted[msg.sender] += _amountdscmint;
        _revertIfhealthFactorisbroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, _amountdscmint);
        if (!success) {
            revert DSCEngine_MintfunctionisFailed();
        }
    }

    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.staleChecklatestprice();
        // $100e18 USD Debt
        // 1 ETH = 2000 USD
        // The returned value from Chainlink will be 2000 * 1e8

        return ((usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAllpriceFeeds() public view returns (address[] memory) {
        return Pricefeeds;
    }

    function getAccountInfo(
        address user
    )
        public
        view
        returns (uint256 _totalDSCmint, uint256 _totalcollateralmint)
    {
        (_totalDSCmint, _totalcollateralmint) = getAccountInformation(user);
    }

    function getCollateralBalanceOfUser(
        address user,
        address token
    ) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getDscmintedvalue() public view returns (uint256) {
        return s_DSCMinted[msg.sender];
    }

    function getCollateralTokens() public view returns (address[] memory) {
        return s_collateralTokens;
    }
}
