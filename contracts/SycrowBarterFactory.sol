// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./interfaces/Ownable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/ISyCrowBarterFactory.sol";
import "./interfaces/ISyCrowBarter.sol";
import "./interfaces/IERC20.sol";


contract SyCrowBarterFactory is ISyCrowBarterFactory, Ownable, ReentrancyGuard {
    address public immutable _WETH;
    address public override feeCollector;
    address[] public override allBarters;

    bool public override isPaused;
    bool public usePriceFeeds;

    uint256 public override totalBarterDeployed;
    // Fees are treated as the amount in the primary token unless _usePriceFeeds is enabled
    // Then we treat them as USD
    uint256 private _baseFee;
    uint256 private _allBarterLength;

    AggregatorV3Interface internal _priceFeed;

    mapping(address => address[]) private _userBarters;

    constructor(
        uint256 baseFee,
        address priceFeed,
        address WETH
    ) {
        isPaused = false;
        usePriceFeeds = false;
        totalBarterDeployed = 0;
        _allBarterLength = 0;

        _baseFee = baseFee;
        feeCollector = _msgSender();
        _priceFeed = AggregatorV3Interface(priceFeed);

        _WETH = WETH;
    }

    function nonZero(uint256 value) internal pure {
        require(value > 0, "SyCrowBarterFactory: ZERO_VALUE");
    }

    function getFee() public view override returns (uint256) {
        if (usePriceFeeds) {
            return computeFee(_baseFee);
        }
        return _baseFee;
    }

    function setFeeCollector(address _feeCollector)
        external
        override
        onlyOwner
    {
        feeCollector = _feeCollector;
    }

    modifier isChild() {
        require(
            ISyCrowBarter(msg.sender).factory() == address(this),
            "SyCrowBarterFactory: FORBIDDEN"
        );
        _;
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
        require(
            deposited > 0 && expected > 0,
            "SyCrowBarterFactory: NON_ZERO_AMOUNTS"
        );
        require(
            deadline >= block.timestamp,
            "SyCrowBarterFactory: DEADLINE_IN_THE_PAST"
        );

        uint256 totalFees = getFee();

        if (barterType == ISyCrowBarterType.ETH_FOR_TOKEN) {
            require(
                msg.value >= totalFees + deposited,
                "SyCrowBarterFactory: PAYMENT_UNVALUED"
            );
            require(inToken == _WETH, "SyCrowBarterFactory: WRONG_IN_TOKEN");
        } else {
            require(
                msg.value >= totalFees,
                "SyCrowBarterFactory: PAYMENT_UNVALUED"
            );
            require(
                IERC20(inToken).balanceOf(msg.sender) >= deposited,
                "SyCrowBarter: INSUFFICIENT_BALANCE"
            );
        }

        address barter = deployBarter();

        if (barterType == ISyCrowBarterType.ETH_FOR_TOKEN) {
            IWETH(_WETH).deposit{value: deposited}();
            TransferHelper.safeTransfer(_WETH, barter, deposited);
        } else {
            TransferHelper.safeTransferFrom(
                inToken,
                msg.sender,
                barter,
                deposited
            );
        }

        TransferHelper.safeTransferETH(feeCollector, totalFees);

        SyCrowBarter syCrowBarter = SyCrowBarter(payable(barter));

        require(
            syCrowBarter.initialize(
                barterType,
                inToken,
                outToken,
                deposited,
                expected,
                deadline,
                allowMultiBarter,
                _WETH
            ),
            "SyCrowBarterFactory: INITIALIZATION_FAILED"
        );

        syCrowBarter.transferOwnership(msg.sender);

        if (!isPrivate) {
            allBarters.push(barter);
        }
        
        _userBarters[msg.sender].push(barter);

        emit Creation(
            barterType,
            msg.sender,
            barter,
            inToken,
            outToken,
            deadline,
            isPrivate
        );

        return barter;
    }

    function allBartersLength() external view override returns (uint256) {
        return allBarters.length;
    }

    function getUserBarters(address userAddress)
        external
        view
        returns (address[] memory barters)
    {
        return _userBarters[userAddress];
    }

    function getUserBartersLength(address userAddress)
        external
        view
        returns (uint256)
    {
        return _userBarters[userAddress].length;
    }

    function getUserBarter(address userAddress, uint256 index)
        external
        view
        returns (address)
    {
        return _userBarters[userAddress][index];
    }

    function setPause(bool _pause) external override onlyOwner {
        isPaused = _pause;
    }

    // base fee and listing fee in dollars when enabling and in ETH when disabled
    function setUsePriceFeeds(
        uint256 baseFee,
        bool enable
    ) external override onlyOwner {
        usePriceFeeds = enable;
        _baseFee = baseFee;
    }

    function computeFee(uint256 amount) internal view returns (uint256) {
        (, int256 price, , , ) = _priceFeed.latestRoundData();
        return (amount / (uint256(price) * 10**10)) * 10**18;
    }

    function notifyTradeByBarter(
        address barter,
        address trader,
        uint256 inAmount,
        uint256 outAmount
    ) external isChild {
        emit Trade(barter, trader, inAmount, outAmount);
    }

    function notifyWithdrawFromBarter(
        address barter,
        address trader,
        uint256 value1,
        uint256 value2
    ) external isChild {
        emit Completion(barter, trader, value1, value2);
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
