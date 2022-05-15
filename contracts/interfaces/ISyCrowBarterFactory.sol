// SPDX-License-Identifier: MIT
import "./ISyCrowBarter.sol";

pragma solidity =0.8.13;

interface ISyCrowBarterFactory {
    event SyCrowBarterCreated(
        ISyCrowBarterType _barterType,
        address indexed _createdBy,
        address indexed _barter,
        address _inToken,
        address outToken,
        uint256 _deposited,
        uint256 _expected,
        uint256 _deadline,
        bool _shouldList,
        bool _allowMultiBarter
    );
    event SyCrowTradeByBarter(
        address indexed _barter,
        address indexed _trader,
        uint256 _inAmount,
        uint256 outAmount
    );
    event SyCrowWithdrawFromBater(
        address indexed _barter,
        address indexed _trader,
        uint256 _value1,
        uint256 _value2
    );

    function createTokenForTokenBarter(
        address _inToken,
        address _outToken,
        uint256 _deposited,
        uint256 _expected,
        uint256 _deadline,
        bool _shouldList,
        bool _allowMultiBarter
    ) external returns (address barter);

    function createTokenForEthBarter(
        address _inToken,
        uint256 _deposited,
        uint256 _expected,
        uint256 _deadline,
        bool _shouldList,
        bool _allowMultiBarter
    ) external returns (address barter);

    function createEthForTokenBarter(
        address _outToken,
        uint256 _deposited,
        uint256 _expected,
        uint256 _deadline,
        bool _shouldList,
        bool _allowMultiBarter
    ) external payable returns (address barter);

    function totalBarterCount() external returns (uint);

    function setBaseFee(uint256 _baseFee) external;

    function getBaseFee() external view returns (uint256);

    function getListingFee() external view returns (uint256);

    function setListingFee(uint256 _listingFee) external;

    function setFeeCollector(address _feeCollector) external;

    function getFeeCollector() external view returns (address);

    function allBartersLength() external view returns (uint256);

    function allBarters(uint256) external view returns (address barter);

    function userBartersLength(address _userAddress)
        external
        view
        returns (uint256);

    function userBarters(address _userAddress, uint256 _atIndex)
        external
        view
        returns (address barter);

    function isPaused() external view returns (bool);

    function setPause(bool pause) external;

    function setUsePriceFeeds(
        uint256 _baseFee,
        uint256 _listingFee,
        bool enable
    ) external;

    function isUsingPriceFeeds() external view returns (bool);

    function notifyTradeByBarter(
        address _barter,
        address _trader,
        uint256 _inAmount,
        uint256 outAmount
    ) external;

    function notifyWithdrawFromBarter(
        address _barter,
        address _trader,
        uint256 _value1,
        uint256 _value2
    ) external;
}
