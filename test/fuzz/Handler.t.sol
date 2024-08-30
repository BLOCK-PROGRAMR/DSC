//SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;
import {DecentralizeStablecoin} from "../../src/DecentralizeStablecoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DecentralizeStablecoin public dsc;
    DSCEngine public dsce;
    // ERC20Mock public weth; //this is one test ERC20-tokenaddress
    // ERC20Mock public wbtc; //this is one test ERC20-tokenaddress
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;
    address public _weth;
    address public _wbtc;
    uint256 public _timeCount = 0;
    address[] public h_address;

    constructor(DecentralizeStablecoin _dsc, DSCEngine _dsce) {
        dsc = _dsc;
        dsce = _dsce;
        address[] memory collateralTokens = dsce.getCollateralTokens();
        // weth = ERC20Mock(collateralTokens[0]);
        // wbtc = ERC20Mock(collateralTokens[1]);
        _weth = collateralTokens[0];
        _wbtc = collateralTokens[1];
    }

    function MintDsc(uint256 _amount, uint256 _amountseed) public {
        if (h_address.length == 0) {
            return;
        }
        address sender = h_address[_amountseed % h_address.length];
        (uint256 _totalDSCmint, uint256 _totalcollateralmint) = dsce
            .getAccountInfo(sender);
        int256 _MaxdscMint = (int256(_totalcollateralmint) / 2) -
            int256(_totalDSCmint);
        if (_MaxdscMint < 0) {
            return;
        }
        _amount = bound(_amount, 0, uint256(_MaxdscMint));
        vm.startPrank(sender);
        dsce.mintDSC(_amount);
        vm.stopPrank();
        _timeCount += 1;
    }

    function depositingCollateral(
        uint256 collateralseed,
        uint256 _amountcollateral
    ) public {
        address collateraladdr = getCollateral(collateralseed);
        _amountcollateral = bound(_amountcollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        ERC20Mock(collateraladdr).mint(msg.sender, _amountcollateral);
        ERC20Mock(collateraladdr).approve(address(dsce), _amountcollateral);
        dsce.depositCollateral(collateraladdr, _amountcollateral);
        vm.stopPrank();
        h_address.push(msg.sender);
    }

    function getCollateral(uint256 seed) private view returns (address) {
        if (seed % 2 == 0) {
            return _weth;
        }
        return _wbtc;
    }

    function _redeemCollateral(
        address _collateralAddr,
        uint256 _amountcollateral
    ) public {
        uint256 MaxamountCollateral = dsce.getCollateralBalanceOfUser(
            _collateralAddr,
            msg.sender
        );

        _amountcollateral = bound(_amountcollateral, 0, MaxamountCollateral);
        if (_amountcollateral == 0) {
            return;
        }
        dsce.redeemCollateral(_collateralAddr, _amountcollateral);
    }
}
