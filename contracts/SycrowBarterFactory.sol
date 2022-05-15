// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./interfaces/ISyCrowBarterFactory.sol";
import "./interfaces/IERC20.sol";
import "./SyCrowBarter.sol";

contract SyCrowBarterFactory is ISyCrowBarterFactory, Ownable {
    address public immutable WETH;

    bool private _paused;
    bool private _usePriceFeeds;

    uint256 private _totalBarterDeployed;
    // Fees are treated as the amount in the primary token unless _usePriceFeeds is enabled
    // Then we treat them as USD
    uint256 private _baseFee;
    uint256 private _listingFee;

    address private _feeCollector;

    address[] private _barters;

    AggregatorV3Interface internal _priceFeed;

    mapping(address => address[]) _userBarters;

    constructor(
        uint256 baseFee,
        uint256 listingFee,
        address priceFeed,
        address _WETH
    ) {
        _paused = false;
        _usePriceFeeds = false;
        _baseFee = baseFee;
        _listingFee = listingFee;
        _feeCollector = _msgSender();
        _priceFeed = AggregatorV3Interface(priceFeed);
        _totalBarterDeployed = 0;
        WETH = _WETH;
        _barters = new address[];
    }

    function nonZero(uint256 value) internal {
        require(value > 0, "SyCrowBarterFactory: ZERO_VALUE");
    }

    function totalBarterCount() external returns (uint256) {
        return _totalBarterDeployed;
    }

    modifier isChild() {
        ISyCrowBarter iscrw = ISyCrowBarter(msg.sender);
        require(iscrw.factory() == address(this), "SyCrowBarterFactory: FORBIDDEN");
        _;
    }

    function createTokenForTokenBarter(
        address inToken,
        address outToken,
        uint256 deposited,
        uint256 expected,
        uint256 deadline,
        bool shouldList,
        bool allowMultiBarter
    ) external override returns (address barter) {
        require(inToken != outToken, "SyCrowBarterFactory: IDENTICAL_TOKENS");

        uint256 totalFees = getBaseFee();

        if (shouldList) {
            totalFees = totalFees + getListingFee();
        }

        require (msg.value >= totalFees, "SyCrowBarterFactory: PAYMENT_UNVALUED");

        require(
            _deadline >= block.timestamp,
            "SyCrowBarterFactory: DEADLINE_IN_THE_PAST"
        );

        nonZero(deposited);
        nonZero(expected);

        require(
            IERC20(inToken).balanceOf(msg.sender) >= deposited,
            "SyCrowBarter: INSUFFICIENT_BALANCE"
        );

        address deployedBarterAddress = deployBarter();

        TransferHelper.safeTransferFrom(
            inToken,
            msg.sender,
            deployedBarterAddress,
            deposited
        );

        TransferHelper.safeTransferETH(_feeCollector, msg.value);

        SyCrowBarter syCrowBarter = SyCrowBarter(deployedBarterAddress);

        require(syCrowBarter.initialize(
            ISyCrowBarterType.TOKEN_FOR_TOKEN,
            inToken,
            outToken,
            deposited,
            expected,
            deadline,
            allowMultiBarter,
            WETH
        ), "SyCrowBarterFactory: INITIALIZATION_FAILED");

        syCrowBarter.transferOwnership(msg.sender);

        notifyBarterCreated(ISyCrowBarterType.ETH_FOR_TOKEN, msg.sender, deployedBarterAddress, inToken, outToken, deposited, expected, deadline, shouldList, allowMultiBarter);

        return deployedBarterAddress;
    }

    function createTokenForEthBarter(
        address inToken,
        uint256 deposited,
        uint256 expected,
        uint256 deadline,
        bool shouldList,
        bool allowMultiBarter
    ) external override returns (address barter) {
        uint256 totalFees = getBaseFee();

        if (shouldList) {
            totalFees = totalFees + getListingFee();
        }

        require (msg.value >= totalFees, "SyCrowBarterFactory: PAYMENT_UNVALUED");

        require(
            _deadline >= block.timestamp,
            "SyCrowBarterFactory: DEADLINE_IN_THE_PAST"
        );

        nonZero(deposited);
        nonZero(expected);

        require(
            IERC20(inToken).balanceOf(msg.sender) >= deposited,
            "SyCrowBarter: INSUFFICIENT_BALANCE"
        );

        address deployedBarterAddress = deployBarter();

        TransferHelper.safeTransferFrom(
            inToken,
            msg.sender,
            deployedBarterAddress,
            deposited
        );

        TransferHelper.safeTransferETH(_feeCollector, msg.value);

        SyCrowBarter syCrowBarter = SyCrowBarter(deployedBarterAddress);

        require (syCrowBarter.initialize(
            ISyCrowBarterType.TOKEN_FOR_ETH,
            inToken,
            outToken,
            deposited,
            expected,
            deadline,
            allowMultiBarter,
            WETH
        ), "SyCrowBarterFactory: INITIALIZATION_FAILED");

        syCrowBarter.transferOwnership(msg.sender);

        notifyBarterCreated(ISyCrowBarterType.ETH_FOR_TOKEN, msg.sender, deployedBarterAddress, inToken, outToken, deposited, expected, deadline, shouldList, allowMultiBarter);

        return deployedBarterAddress;
    }

    function createEthForTokenBarter(
        address outToken,
        uint256 deposited,
        uint256 expected,
        uint256 deadline,
        bool shouldList,
        bool allowMultiBarter
    ) external payable override returns (address barter) {
        require(
            _deadline >= block.timestamp,
            "SyCrowBarterFactory: DEADLINE_IN_THE_PAST"
        );

        uint256 totalFees = getBaseFee();

        if (shouldList) {
            totalFees = totalFees + getListingFee();
        }

        nonZero(deposited);
        nonZero(expected);

        require(msg.value >= (deposited + totalFees), "SyCrowBarterFactory: INSUFFICIENT_BALANCE");

        address deployedBarterAddress = deployBarter();

        IWETH(WETH).deposit{value: deposited}();

        TransferHelper.safeTransfer(WETH, deployedBarterAddress, deposited);
        
        TransferHelper.safeTransferETH(_feeCollector, msg.value);

        SyCrowBarter syCrowBarter = SyCrowBarter(deployedBarterAddress);

        require (syCrowBarter.initialize(
            ISyCrowBarterType.ETH_FOR_TOKEN,
            WETH,
            outToken,
            deposited,
            expected,
            deadline,
            allowMultiBarter,
            WETH
        ), "SyCrowBarterFactory: INITIALIZATION_FAILED");
        
        syCrowBarter.transferOwnership(msg.sender);

        notifyBarterCreated(ISyCrowBarterType.ETH_FOR_TOKEN, msg.sender, deployedBarterAddress, WETH, outToken, deposited, expected, deadline, shouldList, allowMultiBarter);

        return deployedBarterAddress;
    }

    function setBaseFee(uint256 baseFee) external override onlyOwner {
        _baseFee = baseFee;
    }

    function getBaseFee() external view override returns (uint256) {
        if (_usePriceFeeds) {
            return computeFee(_baseFee);
        }
        return _baseFee;
    }

    function getListingFee() external view override returns (uint256) {
        if (_usePriceFeeds) {
            return computeFee(_listingFee);
        }
        return _listingFee;
    }

    function setListingFee(uint256 listingFee) external override onlyOwner {
        _listingFee = listingFee;
    }

    function setFeeCollector(address feeCollector) external override onlyOwner {
        _feeCollector = feeCollector;
    }

    function getFeeCollector() external view override returns (address) {
        return _feeCollector;
    }

    function allBartersLength() external view override returns (uint256) {
        return _barters.length;
    }

    function allBarters(uint256 index)
        external
        view
        override
        returns (address barter)
    {
        return _barters[index];
    }

    function userBartersLength(address userAddress)
        external
        view
        override
        returns (uint256)
    {
        return _userBarters[userAddress].length;
    }

    function userBarters(address userAddress, uint256 index)
        external
        view
        override
        returns (address barter)
    {
        return _userBarters[userAddress][index];
    }

    function isPaused() external view override returns (bool) {
        return _paused;
    }

    function setPause(bool pause) external override onlyOwner {
        _paused = pause;
    }

    // base fee and listing fee in dollars when enabling and in ETH when disabled
    function setUsePriceFeeds(
        uint256 baseFee,
        uint256 listingFee,
        bool enable
    ) external override onlyOwner {
        _usePriceFeeds = enable;
        _baseFee = baseFee;
        _listingFee = listingFee;
    }

    function computeFee(uint256 amount) internal returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (amount / (uint256(price) * 10**10)) * 10**18;
    }

    function isUsingPriceFeeds() external view override returns (bool) {
        return _usePriceFeeds;
    }

    function notifyBarterCreated(
        ISyCrowBarterType _barterType,
        address _createdBy,
        address _barter,
        address _inToken,
        address outToken,
        uint256 _deposited,
        uint256 _expected,
        uint256 _deadline,
        bool _shouldList,
        bool _allowMultiBarter
    ) internal {
        _barters.push(_barter);

        if(_userBarters[_createdBy] == address(0x0000000000000000)){
            _userBarters[_createdBy] = new address[];
        }

        _userBarters[_createdBy].push(_barter);

        emit SyCrowBarterCreated(
            _barterType,
            _createdBy,
            _barter,
            _inToken,
            outToken,
            _deposited,
            _expected,
            _deadline,
            _shouldList,
            _allowMultiBarter
        );
    }

    function notifyTradeByBarter(
        address _barter,
        address _trader,
        uint256 _inAmount,
        uint256 outAmount
    ) external isChild {
        emit SyCrowTradeByBarter(_barter, _trader, _inAmount, outAmount);
    }

    function notifyWithdrawFromBarter(
        address _barter,
        address _trader,
        uint256 _value1,
        uint256 _value2
    ) external isChild {
        emit SyCrowWithdrawFromBater(_barter, _trader, _value1, _value2);

        for (uint256 index = 0; index < _barters.length; index++) {
            if (_barters[index] == _barter) {
                delete _barters[index];
                break;
            }
        }
    }

    function deployBarter() internal returns (address barter) {
        bytes memory bytecode = type(SyCrowBarter).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(address(this), _totalBarterDeployed)
        );
        assembly {
            barter := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        _totalBarterDeployed = _totalBarterDeployed + 1;
        return barter;
    }
}
