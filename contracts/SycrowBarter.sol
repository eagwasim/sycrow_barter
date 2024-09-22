// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./interfaces/Ownable.sol";
import "./interfaces/ReentrancyGuard.sol";
import "./interfaces/ISyCrowBarterFactory.sol";
import "./interfaces/ISyCrowBarter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";
import "./libraries/TransferHelper.sol";

contract SyCrowBarter is ISyCrowBarter, Ownable, ReentrancyGuard {
    address public immutable override factory;
    uint256 public override totalTradeAmount;

    bool public override allowMultiBarter;
    bool public override completed = false;

    uint256 public override deadline;
    ISyCrowBarterType public override barterType;

    address private WETH;
    bool public _initialized = false;
    address private _depositedTokenAddress;
    address private _expectedTokenAddress;
    uint256 private _depositedAmount;
    uint256 private _expectedAmount;

    BaterTrade[] private _trades;

    struct BaterTrade {
        address _trader;
        uint256 _amountIn;
        uint256 _amountOut;
    }

    modifier checkActive() {
        require(deadline >= block.timestamp && totalTradeAmount < _expectedAmount, "SyCrowBarter: INACTIVE");
        _;
    }

    modifier checkInActive() {
        require(deadline < block.timestamp || totalTradeAmount >= _expectedAmount, "SyCrowBarter: ACTIVE");
        _;
    }

    modifier initialized() {
        require(_initialized, "SyCrowBarter: NOT_INITIALIZED");
        _;
    }

    modifier checkPaused() {
        ISyCrowBarterFactory isycrFactory = ISyCrowBarterFactory(factory);
        require(!isycrFactory.isPaused(), "SyCrowBarter: CONTRACT_PAUSED");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(
        ISyCrowBarterType _barterType,
        address inToken,
        address outToken,
        uint256 amountDeposited,
        uint256 amountExpected,
        uint256 _deadline,
        bool _allowMultiBarter,
        address _WETH
    ) external override returns (bool) {
        require(msg.sender == factory, "SyCrowBarter: FORBIDDEN");
        require(!_initialized, "SyCrowBarter: ALREADY_INITIALIZED");
        require(_deadline >= block.timestamp, "SyCrowBarter: PAST_DEADLINE");
        require(IERC20(inToken).balanceOf(address(this)) >= amountDeposited, "SyCrowBarter: INSUFFICIENT_DEPOSIT");

        deadline = _deadline;
        _depositedTokenAddress = inToken;
        _expectedTokenAddress = outToken;
        _depositedAmount = amountDeposited;
        _expectedAmount = amountExpected;
        barterType = _barterType;
        allowMultiBarter = _allowMultiBarter;
        WETH = _WETH;
        _initialized = true;

        return _initialized;
    }

    function getAmounts() external view override initialized returns (uint256, uint256) {
        return (_depositedAmount, _expectedAmount);
    }

    function getTokens() external view override initialized returns (address, address) {
        return (_depositedTokenAddress, _expectedTokenAddress);
    }

    function getTrades()
    external
    view
    override
    initialized
    returns (address[] memory, uint256[] memory, uint256[] memory)
    {
        address[] memory traders = new address[](_trades.length);
        uint256[] memory amountsIn = new uint256[](_trades.length);
        uint256[] memory amountsOut = new uint256[](_trades.length);

        for (uint256 i = 0; i < _trades.length; i++) {
            traders[i] = _trades[i]._trader;
            amountsIn[i] = _trades[i]._amountIn;
            amountsOut[i] = _trades[i]._amountOut;
        }

        return (traders, amountsIn, amountsOut);
    }

    function tradeTokenForToken(uint256 inAmount)
    external
    override
    checkActive
    initialized
    checkPaused
    nonReentrant
    {
        _validateTrade(inAmount);
        _tradeTokenForToken(inAmount);
    }

    function tradeTokenForEth(uint256 inAmount)
    external
    override
    checkActive
    initialized
    checkPaused
    nonReentrant
    {
        _validateTrade(inAmount);
        _tradeTokenForEth(inAmount);
    }

    function tradeEthForToken(uint256 inAmount)
    external
    payable
    override
    checkActive
    initialized
    checkPaused
    nonReentrant
    {
        require(inAmount == msg.value, "SyCrowBarter: INVALID_AMOUNT");
        _tradeEthForToken(inAmount);
    }

    function _validateTrade(uint256 inAmount) internal view {
        if (!allowMultiBarter) {
            require(inAmount >= _expectedAmount, "SyCrowBarter: AMOUNT_LOWER_THAN_REQUIRED");
        }
    }

    function _tradeTokenForToken(uint256 inAmount) internal {
        require(IERC20(_expectedTokenAddress).balanceOf(msg.sender) >= inAmount, "SyCrowBarter: INSUFFICIENT_BALANCE");
        uint256 outAmount = getTradeOutAmount(inAmount);
        require(IERC20(_depositedTokenAddress).balanceOf(address(this)) >= outAmount, "SyCrowBarter: INSUFFICIENT_CONTRACT_BALANCE");

        TransferHelper.safeTransferFrom(_expectedTokenAddress, msg.sender, address(this), inAmount);
        TransferHelper.safeTransfer(_depositedTokenAddress, msg.sender, outAmount);

        _recordTrade(msg.sender, inAmount, outAmount);
    }

    function _tradeTokenForEth(uint256 inAmount) internal {
        require(IERC20(_expectedTokenAddress).balanceOf(msg.sender) >= inAmount, "SyCrowBarter: INSUFFICIENT_BALANCE");
        uint256 outAmount = getTradeOutAmount(inAmount);
        require(IERC20(WETH).balanceOf(address(this)) >= outAmount, "SyCrowBarter: INSUFFICIENT_CONTRACT_BALANCE");

        TransferHelper.safeTransferFrom(_expectedTokenAddress, msg.sender, address(this), inAmount);
        IWETH(WETH).withdraw(outAmount);
        TransferHelper.safeTransferETH(msg.sender, outAmount);

        _recordTrade(msg.sender, inAmount, outAmount);
    }

    function _tradeEthForToken(uint256 inAmount) internal {
        uint256 outAmount = getTradeOutAmount(inAmount);
        require(IERC20(_depositedTokenAddress).balanceOf(address(this)) >= outAmount, "SyCrowBarter: INSUFFICIENT_CONTRACT_BALANCE");

        IWETH(WETH).deposit{value: inAmount}();
        TransferHelper.safeTransfer(_depositedTokenAddress, msg.sender, outAmount);

        _recordTrade(msg.sender, inAmount, outAmount);
    }

    function _recordTrade(address trader, uint256 inAmount, uint256 outAmount) internal {
        _trades.push(BaterTrade(trader, inAmount, outAmount));
        totalTradeAmount += inAmount;
        ISyCrowBarterFactory(factory).notifyTradeByBarter(address(this), trader, inAmount, outAmount);
    }

    function withdraw() external override checkInActive initialized onlyOwner {
        _withdrawFunds();
        completed = true;
    }

    function _withdrawFunds() internal {
        uint256 ethBalance = IERC20(WETH).balanceOf(address(this));
        uint256 expectedTokenBalance = IERC20(_expectedTokenAddress).balanceOf(address(this));
        uint256 depositedTokenBalance = IERC20(_depositedTokenAddress).balanceOf(address(this));

        if (ethBalance > 0) {
            IWETH(WETH).withdraw(ethBalance);
            TransferHelper.safeTransferETH(msg.sender, ethBalance);
        }

        if (expectedTokenBalance > 0) {
            TransferHelper.safeTransfer(_expectedTokenAddress, msg.sender, expectedTokenBalance);
        }

        if (depositedTokenBalance > 0) {
            TransferHelper.safeTransfer(_depositedTokenAddress, msg.sender, depositedTokenBalance);
        }

        ISyCrowBarterFactory(factory).notifyWithdrawFromBarter(address(this), msg.sender, depositedTokenBalance, ethBalance);
    }

    function getTradeOutAmount(uint256 amount) public view returns (uint256) {
        return (amount * _depositedAmount) / _expectedAmount;
    }

    receive() external payable {}
    fallback() external payable {}
}
