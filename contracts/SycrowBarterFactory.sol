// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./interfaces/ISyCrowBarterFactory.sol";
import "./interfaces/IERC20.sol";
import "./SyCrowBarter.sol";

contract SyCrowBarterFactory is ISyCrowBarterFactory, Ownable {
    address public immutable _WETH;
    address public override feeCollector;
    address[] public override allBarters;

    bool public override isPaused;
    bool public  usePriceFeeds;
    
    uint256 public override totalBarterDeployed;
    // Fees are treated as the amount in the primary token unless _usePriceFeeds is enabled
    // Then we treat them as USD
    uint256 private _baseFee;
    uint256 private _listingFee;

    AggregatorV3Interface internal _priceFeed;

    mapping(address => address[]) private _userBarters;

    constructor(
        uint256 baseFee,
        uint256 listingFee,
        address priceFeed,
        address WETH
    ) {
        isPaused = false;
        usePriceFeeds = false;
        totalBarterDeployed = 0;

        _baseFee = baseFee;
        _listingFee = listingFee;
        feeCollector = _msgSender();
        _priceFeed = AggregatorV3Interface(priceFeed);
        
        _WETH = WETH;
    }

    function nonZero(uint256 value) internal pure {
        require(value > 0, "SyCrowBarterFactory: ZERO_VALUE");
    }

    function getFees() public view override returns (uint256, uint256) {
        if (usePriceFeeds) {
            return (computeFee(_baseFee), computeFee(_listingFee));
        }
        return (_baseFee , _listingFee);
    }

    function setFeeCollector(address _feeCollector) external override onlyOwner {
        feeCollector = _feeCollector;
    }

    modifier isChild() {
        require(ISyCrowBarter(msg.sender).factory() == address(this), "SyCrowBarterFactory: FORBIDDEN");
        _;
    }

    function createBarter(
        address inToken,
        address outToken,
        uint256 deposited,
        uint256 expected,
        uint256 deadline,
        ISyCrowBarterType barterType,
        bool shouldList,
        bool allowMultiBarter
    ) external override payable returns (address barter) {
        require(inToken != outToken, "SyCrowBarterFactory: IDENTICAL_TOKENS");
        require(deposited > 0 && expected > 0, "SyCrowBarterFactory: NON_ZERO_AMOUNTS");
        require(
            deadline >= block.timestamp,
            "SyCrowBarterFactory: DEADLINE_IN_THE_PAST"
        );

        uint256 totalFees = 0;
        
        if (shouldList) {
            (uint256 baseFee, uint256 listingFee) = getFees();
            totalFees = baseFee + listingFee;
        } else { 
            (uint256 baseFee, ) = getFees();
            totalFees = baseFee;
        }

        if (barterType == ISyCrowBarterType.ETH_FOR_TOKEN) {
            require (msg.value >= totalFees + deposited, "SyCrowBarterFactory: PAYMENT_UNVALUED");
            require (inToken == _WETH, "SyCrowBarterFactory: WRONG_IN_TOKEN");
        } else {
            require (msg.value >= totalFees, "SyCrowBarterFactory: PAYMENT_UNVALUED");
            require(IERC20(inToken).balanceOf(msg.sender) >= deposited, "SyCrowBarter: INSUFFICIENT_BALANCE");
        }
        
        address deployedBarterAddress = deployBarter();

        if (barterType == ISyCrowBarterType.ETH_FOR_TOKEN){
            IWETH(_WETH).deposit{value: deposited}();
            TransferHelper.safeTransfer(_WETH, deployedBarterAddress, deposited);
        } else {
            TransferHelper.safeTransferFrom(inToken, msg.sender, deployedBarterAddress, deposited);
        }
        
        TransferHelper.safeTransferETH(feeCollector, totalFees);

        SyCrowBarter syCrowBarter = SyCrowBarter(deployedBarterAddress);
      
        require(syCrowBarter.initialize(
            barterType,
            inToken,
            outToken,
            deposited,
            expected,
            deadline,
            allowMultiBarter,
            _WETH
        ), "SyCrowBarterFactory: INITIALIZATION_FAILED");

        syCrowBarter.transferOwnership(msg.sender);

        allBarters.push(deployedBarterAddress);
        _userBarters[msg.sender].push(deployedBarterAddress);
        
        emit SyCrowBarterCreated(barterType, msg.sender, deployedBarterAddress, inToken, outToken, deadline, shouldList);
        
        return deployedBarterAddress;
    }

    function allBartersLength() external view override returns (uint256) {
        return allBarters.length;
    }

    function getUserBarters(address userAddress) external view returns (address[] memory barters) {
        return _userBarters[userAddress];
    }

    function setPause(bool _pause) external override onlyOwner {
        isPaused = _pause;
    }

    // base fee and listing fee in dollars when enabling and in ETH when disabled
    function setUsePriceFeeds(
        uint256 baseFee,
        uint256 listingFee,
        bool enable
    ) external override onlyOwner {
         usePriceFeeds = enable;
        _baseFee = baseFee;
        _listingFee = listingFee;
    }

    function computeFee(uint256 amount) internal view returns (uint256) {
        (, int256 price, , , ) = _priceFeed.latestRoundData();
        return (amount / (uint256(price) * 10**10)) * 10**18;
    }

    function notifyTradeByBarter(
        address _barter,
        address _trader,
        uint256 _inAmount,
        uint256 _outAmount
    ) external isChild {
        emit SyCrowTradeByBarter(_barter, _trader, _inAmount, _outAmount);
    }

    function notifyWithdrawFromBarter(
        address _barter,
        address _trader,
        uint256 _value1,
        uint256 _value2
    ) external isChild {
        emit SyCrowWithdrawFromBater(_barter, _trader, _value1, _value2);

        for (uint256 index = 0; index < allBarters.length; index++) {
            if (allBarters[index] == _barter) {
                delete allBarters[index];
                break;
            }
        }
    }

    function deployBarter() internal returns (address barter) {
        bytes memory bytecode = type(SyCrowBarter).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(address(this), totalBarterDeployed)
        );
        assembly {
            barter := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        totalBarterDeployed = totalBarterDeployed + 1;
        return barter;
    }
}
