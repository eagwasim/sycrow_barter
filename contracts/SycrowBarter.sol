// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISyCrowBarterFactory.sol";
import "./interfaces/IERC20.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IWETH.sol";

contract SyCrowBarter is ISyCrowBarter, Ownable {
    address public immutable override factory;

    address private  WETH;

    uint256 private _deadline;

    bool public _initialized = false;

    address private _depositedTokenAddress;
    address private _expectedTokenAddress;

    uint256 private _depositedAmount;
    uint256 private _expectedAmount;
    uint256 private _totalTradeAmount;

    bool private _allowMultiBarter;

    ISyCrowBarterType private _barterType;
    BaterTrade[] private _trades;

    struct BaterTrade {
        address _trader;
        uint256 _amountIn;
        uint256 _amountOut;
    }

    modifier checkActive() {
        require(
            _deadline >= block.timestamp && _totalTradeAmount < _expectedAmount,
            "SyCrowBarter: INACTIVE"
        );
        _;
    }

    modifier checkBarterType(ISyCrowBarterType barterType) {
        require(barterType == _barterType, "SyCrowBarter: INVALID_BARTER_TYPE");
        _;
    }

    modifier checkInActive() {
        require(
            _deadline < block.timestamp || _totalTradeAmount >= _expectedAmount,
            "SyCrowBarter: ACTIVE"
        );
        _;
    }

    modifier initialized() {
        require(_initialized, "SyCrowBarter: NOT_INITIALIZED");
        _;
    }

    modifier multiTradeEnabled() {
        require(_allowMultiBarter, "SyCrowBarter: MULTI_TRADE_NOT_ENABLED");
        _;
    }

    modifier checkPaused() {
        ISyCrowBarterFactory isycrFactory = ISyCrowBarterFactory(factory);
        require(!isycrFactory.isPaused(), "SyCrowBarter: Base Contract Paused");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(
        ISyCrowBarterType barterType,
        address inToken,
        address outToken,
        uint256 amountDeposited,
        uint256 amountExpected,
        uint256 deadline,
        bool allowMultiBarter,
        address _WETH
    ) external returns (bool) {
        require(msg.sender == factory, "SyCrowBarter: FORBIDDEN");

        require(!_initialized, "SyCrowBarter: ALREADY_INITIALIZED");
        require(deadline < block.timestamp, "SyCrowBarter: PAST_DEADLINE");

        require(
            IERC20(inToken).balanceOf(address(this)) >= amountDeposited,
            "SyCrowBarter: INSUFFICIENT_DEPOSIT"
        );

        _deadline = deadline;

        _depositedTokenAddress = inToken;
        _expectedTokenAddress = outToken;

        _depositedAmount = amountDeposited;
        _expectedAmount = amountExpected;

        _barterType = barterType;
        _allowMultiBarter = allowMultiBarter;
        WETH = _WETH;
        _initialized = true;

        return _initialized;
    }

    function getAmounts()
        external
        view
        override
        initialized
        returns (uint256, uint256)
    {
        return (_depositedAmount, _expectedAmount);
    }

    function getTokens()
        external
        view
        override
        initialized
        returns (address, address)
    {
        return (_depositedTokenAddress, _expectedTokenAddress);
    }

    function getBarterBalance()
        external
        view
        override
        initialized
        returns (uint256)
    {
        return _barteredAmount;
    }

    function getDeadline()
        external
        view
        override
        initialized
        returns (uint256)
    {
        return _deadline;
    }

    function getBarterType()
        external
        view
        override
        initialized
        returns (ISyCrowBarterType)
    {
        return _barterType;
    }

    function getTrades()
        external
        view
        override
        initialized
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        address[] memory addresses = new address[](_trades.length);
        uint256[] memory amountsIn = new uint256[](_trades.length);
        uint256[] memory amountsOut = new uint256[](_trades.length);

        for (uint256 i = 0; i < _trades.length; i++) {
            addresses[i] = _trades[i]._trader;
            amountsIn[i] = _trades[i]._amountIn;
            amountsOut[i] = _trades[i]._amountOut;
        }

        return (addresses, amountsIn, amountsOut);
    }

    function tradeTokenForToken(uint256 inAmount)
        external
        override
        checkActive
        initialized
        checkPaused
        multiTradeEnabled
        checkBarterType(ISyCrowBarterType.TOKEN_FOR_TOKEN)
    {
        _tradeTokenForToken(inAmount);
    }

    function tradeTokenForEth(uint256 inAmount)
        external
        override
        checkActive
        initialized
        checkPaused
        multiTradeEnabled
        checkBarterType(ISyCrowBarterType.ETH_FOR_TOKEN)
    {
        _tradeTokenForEth(inAmount);
    }

    function tradeEthForToken(uint256 inAmount)
        external
        override
        checkActive
        initialized
        checkPaused
        multiTradeEnabled
        checkBarterType(ISyCrowBarterType.TOKEN_FOR_ETH)
    {
        _tradeEthForToken{value: msg.value}(inAmount);
    }

    function tradeTokenForToken()
        external
        override
        checkActive
        initialized
        checkPaused
        checkBarterType(ISyCrowBarterType.TOKEN_FOR_TOKEN)
    {
        _tradeTokenForToken(_expectedAmount);
    }

    function tradeTokenForEth()
        external
        override
        checkActive
        initialized
        checkPaused
        checkBarterType(ISyCrowBarterType.ETH_FOR_TOKEN)
    {
        _tradeTokenForEth(_expectedAmount);
    }

    function tradeEthForToken()
        external
        override
        checkActive
        initialized
        checkPaused
        checkBarterType(ISyCrowBarterType.TOKEN_FOR_ETH)
    {
        _tradeEthForToken{value: msg.value}(_expectedAmount);
    }

    function _tradeTokenForToken(uint256 inAmount) internal {
        require(
            IERC20(_expectedTokenAddress).balanceOf(msg.sender) >= amount,
            "SyCrowBarter: INSUFFICIENT_BALANCE"
        );

        uint256 outAmount = _getTradeOutAmount(inAmount);

        require(
            IERC20(_depositedTokenAddress).balanceOf(address(this)) >=
                outAmount,
            "SyCrowBarter: INSUFFICIENT_CONTRACT_BALANCE"
        );

        TransferHelper.safeTransferFrom(
            _expectedTokenAddress,
            msg.sender,
            address(this),
            inAmount
        );
        TransferHelper.safeTransfer(
            _depositedTokenAddress,
            msg.sender,
            outAmount
        );

        _trades.push(BaterTrade(msg.sender, inAmount, outAmount));

        ISyCrowBarterFactory sycrFactory = ISyCrowBarterFactory(factory);
        sycrFactory.notifyTradeByBarter(
            address(this),
            msg.sender,
            inAmount,
            outAmount
        );
    }

    function _tradeTokenForEth(uint256 inAmount) internal {
        require(
            IERC20(_expectedTokenAddress).balanceOf(msg.sender) >= inAmount,
            "SyCrowBarter: INSUFFICIENT_BALANCE"
        );

        uint256 outAmount = _getTradeOutAmount(inAmount);

        IWETH _weth = IWETH(WETH);

        require(
            _weth.balanceOf(address(this)) >= outAmount,
            "SyCrowBarter: INSUFFICIENT_CONTRACT_BALANCE"
        );

        IWETH(WETH).withdraw(outAmount);

        TransferHelper.safeTransferFrom(
            _expectedTokenAddress,
            msg.sender,
            address(this),
            inAmount
        );
        TransferHelper.safeTransferETH(msg.sender, outAmount);

        _trades.push(BaterTrade(msg.sender, inAmount, outAmount));

        ISyCrowBarterFactory sycrFactory = ISyCrowBarterFactory(factory);
        sycrFactory.notifyTradeByBarter(
            address(this),
            msg.sender,
            inAmount,
            outAmount
        );
    }

    function _tradeEthForToken(uint256 inAmount) internal payable {
        require(inAmount == msg.value, "SyCrowBarter: MULTI_TRADE_NOT_ENABLED");

        uint256 outAmount = _getTradeOutAmount(inAmount);

        require(
            IERC20(_depositedTokenAddress).balanceOf(address(this)) >=
                outAmount,
            "SyCrowBarter: INSUFFICIENT_CONTRACT_BALANCE"
        );

        IWETH(WETH).deposit{value: inAmount}();

        TransferHelper.safeTransfer(
            _depositedTokenAddress,
            msg.sender,
            outAmount
        );

        _trades.push(BaterTrade(msg.sender, inAmount, outAmount));

        ISyCrowBarterFactory sycrFactory = ISyCrowBarterFactory(factory);
        sycrFactory.notifyTradeByBarter(
            address(this),
            msg.sender,
            inAmount,
            outAmount
        );
    }

    function withdraw() external override checkInActive initialized onlyOwner {
        IWETH _weth = IWETH(WETH);

        uint256 ethBalance = _weth.balanceOf(address(this));

        if (ethBalance > 0) {
            IWETH(WETH).withdraw(ethBalance);
            TransferHelper.safeTransferETH(msg.sender, ethBalance);
        }

        uint256 expectedTokenBalance = IERC20(_expectedTokenAddress).balanceOf(
            address(this)
        );

        if (expectedTokenBalance > 0) {
            TransferHelper.safeTransfer(
                _expectedTokenAddress,
                msg.sender,
                expectedTokenBalance
            );
        }

        uint256 depositedTokenBalance = IERC20(_depositedTokenAddress)
            .balanceOf(address(this));

        if (depositedTokenBalance > 0) {
            TransferHelper.safeTransfer(
                _depositedTokenAddress,
                msg.sender,
                depositedTokenBalance
            );
        }
        uint256 value1 = 0;
        uint256 value2 = 0;

        if (_barterType == ISyCrowBarterType.ETH_FOR_TOKEN) {
            value1 = ethBalance;
            value2 = expectedTokenBalance;
        } else if (_barterType == ISyCrowBarterType.TOKEN_FOR_TOKEN) {
            value1 = depositedTokenBalance;
            value2 = expectedTokenBalance;
        } else {
            value1 = depositedTokenBalance;
            value2 = ethBalance;
        }

        ISyCrowBarterFactory sycrFactory = ISyCrowBarterFactory(factory);
        
        sycrFactory.notifyWithdrawFromBarter(
            address(this),
            msg.sender,
            value1,
            value2
        );

        selfdestruct(owner);
    }

    function withdraw(address _erc20TokenAddress)
        external
        view
        onlyOwner
        initialized
    {
        require(
            _erc20TokenAddress != _expectedTokenAddress,
            "SyCrowBarter: FORBIDDEN"
        );
        require(
            _erc20TokenAddress != _depositedTokenAddress,
            "SyCrowBarter: FORBIDDEN"
        );

        uint256 erc20TokenBalance = IERC20(_erc20TokenAddress).balanceOf(
            address(this)
        );

        if (erc20TokenBalance > 0) {
            TransferHelper.safeTransfer(
                _depositedTokenAddress,
                msg.sender,
                erc20TokenBalance
            );
        }
    }

    function getTradeOutAmount(uint256 amount)
        external
        view
        initialized
        returns (uint256)
    {
        return _getTradeOutAmount(amount);
    }

    function _getTradeOutAmount(uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * _depositedAmount) / _expectedAmount;
    }
}
