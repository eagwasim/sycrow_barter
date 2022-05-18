// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ISyCrowBarterFactory.sol";
import "./interfaces/IERC20.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IWETH.sol";

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
        require(
            deadline >= block.timestamp && totalTradeAmount < _expectedAmount,
            "SyCrowBarter: INACTIVE"
        );
        _;
    }

    modifier checkBarterType(ISyCrowBarterType _barterType) {
        require(_barterType == barterType, "SyCrowBarter: INVALID_BARTER_TYPE");
        _;
    }

    modifier checkInActive() {
        require(
            deadline < block.timestamp || totalTradeAmount >= _expectedAmount,
            "SyCrowBarter: ACTIVE"
        );
        _;
    }

    modifier initialized() {
        require(_initialized, "SyCrowBarter: NOT_INITIALIZED");
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
        ISyCrowBarterType _barterType,
        address inToken,
        address outToken,
        uint256 amountDeposited,
        uint256 amountExpected,
        uint256 _deadline,
        bool _allowMultiBarter,
        address _WETH
    ) external returns (bool) {
        require(msg.sender == factory, "SyCrowBarter: FORBIDDEN");

        require(!_initialized, "SyCrowBarter: ALREADY_INITIALIZED");
        require(_deadline >= block.timestamp, "SyCrowBarter: PAST_DEADLINE");

        require(
            IERC20(inToken).balanceOf(address(this)) >= amountDeposited,
            "SyCrowBarter: INSUFFICIENT_DEPOSIT"
        );

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
        checkBarterType(ISyCrowBarterType.TOKEN_FOR_TOKEN)
        nonReentrant
    {
        if (!allowMultiBarter) {
            require(
                inAmount >= _expectedAmount,
                "SyCrowBarter: AMOUNT_LOWER_THAN_REQURIRED"
            );
        }
        _tradeTokenForToken(inAmount);
    }

    function tradeTokenForEth(uint256 inAmount)
        external
        override
        checkActive
        initialized
        checkPaused
        checkBarterType(ISyCrowBarterType.ETH_FOR_TOKEN)
        nonReentrant
    {
        if (!allowMultiBarter) {
            require(
                inAmount >= _expectedAmount,
                "SyCrowBarter: AMOUNT_LOWER_THAN_REQURIRED"
            );
        }
        _tradeTokenForEth(inAmount);
    }

    function tradeEthForToken(uint256 inAmount)
        external
        payable
        override
        checkActive
        initialized
        checkPaused
        checkBarterType(ISyCrowBarterType.TOKEN_FOR_ETH)
        nonReentrant
    {
        if (!allowMultiBarter) {
            require(
                msg.value >= _expectedAmount,
                "SyCrowBarter: AMOUNT_LOWER_THAN_REQURIRED"
            );
        }
        _tradeEthForToken(inAmount);
    }

    function _tradeTokenForToken(uint256 inAmount) internal {
        require(
            IERC20(_expectedTokenAddress).balanceOf(msg.sender) >= inAmount,
            "SyCrowBarter: INSUFFICIENT_BALANCE"
        );

        uint256 outAmount = getTradeOutAmount(inAmount);

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

        totalTradeAmount = totalTradeAmount + inAmount;

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

        uint256 outAmount = getTradeOutAmount(inAmount);

        IERC20 _wethErc20 = IERC20(WETH);

        require(
            _wethErc20.balanceOf(address(this)) >= outAmount,
            "SyCrowBarter: INSUFFICIENT_CONTRACT_BALANCE"
        );

        TransferHelper.safeTransferFrom(
            _expectedTokenAddress,
            msg.sender,
            address(this),
            inAmount
        );

        IWETH(WETH).withdraw(outAmount);

        TransferHelper.safeTransferETH(msg.sender, outAmount);

        _trades.push(BaterTrade(msg.sender, inAmount, outAmount));

        totalTradeAmount = totalTradeAmount + inAmount;

        ISyCrowBarterFactory sycrFactory = ISyCrowBarterFactory(factory);

        sycrFactory.notifyTradeByBarter(
            address(this),
            msg.sender,
            inAmount,
            outAmount
        );
        
        completed = true;

        require(completed);
    }

    function _tradeEthForToken(uint256 inAmount) internal {
        require(inAmount == msg.value, "SyCrowBarter: MULTI_TRADE_NOT_ENABLED");

        uint256 outAmount = getTradeOutAmount(inAmount);

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
        totalTradeAmount = totalTradeAmount + inAmount;

        ISyCrowBarterFactory sycrFactory = ISyCrowBarterFactory(factory);
        sycrFactory.notifyTradeByBarter(
            address(this),
            msg.sender,
            inAmount,
            outAmount
        );
    }

    function withdraw() external override checkInActive initialized onlyOwner {
        IERC20 _wethErc20 = IERC20(WETH);

        uint256 ethBalance = _wethErc20.balanceOf(address(this));

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

        if (barterType == ISyCrowBarterType.ETH_FOR_TOKEN) {
            value1 = ethBalance;
            value2 = expectedTokenBalance;
        } else if (barterType == ISyCrowBarterType.TOKEN_FOR_TOKEN) {
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
    }

    function getTradeOutAmount(uint256 amount) public view returns (uint256) {
        return (amount * _depositedAmount) / _expectedAmount;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
