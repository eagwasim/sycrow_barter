contract SyCrowBarterFactory is ISyCrowBarterFactory, Ownable, ReentrancyGuard {
    address public immutable _WETH;
    address public override feeCollector;
    address[] public override allBarters;

    bool public override isPaused;
    bool public usePriceFeeds;
    uint256 public override totalBarterDeployed;

    uint256 private _baseFee;
    address internal _priceFeed;
    mapping(address => address[]) private _userBarters;
    mapping(address => bool) private _childBarters;

    constructor(
        uint256 baseFee,
        address priceFeed,
        address WETH
    ) {
        _baseFee = baseFee;
        _priceFeed = priceFeed;
        _WETH = WETH;
        feeCollector = _msgSender();
    }

    modifier onlyValidChild() {
        require(_childBarters[msg.sender], "SyCrowBarterFactory: FORBIDDEN");
        _;
    }

    function getFee() public view override returns (uint256) {
        return usePriceFeeds ? computeFee(_baseFee) : _baseFee;
    }

    function setFeeCollector(address newCollector) external override onlyOwner {
        feeCollector = newCollector;
    }

    function createBarter(
        address inToken,
        address outToken,
        uint256 deposited,
        uint256 expected,
        uint256 deadline,
        ISyCrowBarterType barterType,
        bool allowMultiBarter,
        bool isPrivate
    ) external payable override returns (address) {
        require(inToken != outToken, "SyCrowBarterFactory: IDENTICAL_TOKENS");
        require(deposited > 0 && expected > 0, "SyCrowBarterFactory: INVALID_AMOUNTS");
        require(deadline >= block.timestamp, "SyCrowBarterFactory: INVALID_DEADLINE");

        uint256 totalFees = getFee();

        if (barterType == ISyCrowBarterType.ETH_FOR_TOKEN) {
            require(msg.value >= totalFees + deposited, "SyCrowBarterFactory: INSUFFICIENT_PAYMENT");
            require(inToken == _WETH, "SyCrowBarterFactory: INVALID_IN_TOKEN");
        } else {
            require(msg.value >= totalFees, "SyCrowBarterFactory: INSUFFICIENT_PAYMENT");
            require(IERC20(inToken).balanceOf(msg.sender) >= deposited, "SyCrowBarter: INSUFFICIENT_BALANCE");
        }

        address barter = deployBarter();
        _handleBarterPayment(inToken, barterType, deposited, barter);

        SyCrowBarter(payable(barter)).initialize(
            barterType,
            inToken,
            outToken,
            deposited,
            expected,
            deadline,
            allowMultiBarter,
            _WETH
        );

        SyCrowBarter(barter).transferOwnership(msg.sender);

        if (!isPrivate) allBarters.push(barter);
        _childBarters[barter] = true;
        _userBarters[msg.sender].push(barter);

        emit Creation(barterType, msg.sender, barter, inToken, outToken, deadline, isPrivate);
        return barter;
    }

    function _handleBarterPayment(address inToken, ISyCrowBarterType barterType, uint256 deposited, address barter) internal {
        if (barterType == ISyCrowBarterType.ETH_FOR_TOKEN) {
            IWETH(_WETH).deposit{value: deposited}();
            TransferHelper.safeTransfer(_WETH, barter, deposited);
        } else {
            TransferHelper.safeTransferFrom(inToken, msg.sender, barter, deposited);
        }
        TransferHelper.safeTransferETH(feeCollector, getFee());
    }

    function setPause(bool pauseStatus) external override onlyOwner {
        isPaused = pauseStatus;
    }

    function setUsePriceFeeds(uint256 baseFee, bool enable) external override onlyOwner {
        usePriceFeeds = enable;
        _baseFee = baseFee;
    }

    function computeFee(uint256 amount) internal view returns (uint256) {
        (, int256 price, , , ) = AggregatorV3Interface(_priceFeed).latestRoundData();
        return (amount * 10**18) / (uint256(price) * 10**10);
    }

    function allBartersLength() external view override returns (uint256) {
        return allBarters.length;
    }

    function getUserBarters(address userAddress) external view returns (address[] memory) {
        return _userBarters[userAddress];
    }

    function getUserBarter(address userAddress, uint256 index) external view returns (address) {
        return _userBarters[userAddress][index];
    }

    function deployBarter() internal returns (address barter) {
        bytes memory bytecode = type(SyCrowBarter).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(address(this), msg.sender, totalBarterDeployed));
        assembly {
            barter := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        totalBarterDeployed++;
    }

    function notifyTradeByBarter(address barter, address trader, uint256 inAmount, uint256 outAmount) external onlyValidChild {
        emit Trade(barter, trader, inAmount, outAmount);
    }

    function notifyWithdrawFromBarter(address barter, address trader, uint256 value1, uint256 value2) external onlyValidChild {
        emit Completion(barter, trader, value1, value2);
    }
}