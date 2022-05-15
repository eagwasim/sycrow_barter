// SPDX-License-Identifier: MIT
import "./ISyCrowBarter.sol";

pragma solidity =0.8.13;

interface ISyCrowBarterFactory {
    event SyCrowBarterCreated(
        ISyCrowBarterType _barterType,
        address indexed _createdBy,
        address indexed _barter,
        address _inToken,
        address _outToken,
        uint256 _deadline,
        bool _shouldList
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

    function createBarter(
        address _inToken,
        address _outToken,
        uint256 _deposited,
        uint256 _expected,
        uint256 _deadline,
        ISyCrowBarterType _type,
        bool _shouldList,
        bool _allowMultiBarter
    ) external payable returns (address barter);


    function totalBarterDeployed() external returns (uint);

    function getFees() external returns (uint256 baseFee, uint256 listingFee);

    function setFeeCollector(address _feeCollector) external;

    function feeCollector() external view returns (address);

    function allBartersLength() external view returns (uint256);

    function allBarters(uint256) external view returns (address barter);

    function getUserBarters(address userAddress) external view returns (address[] memory barters);

    function isPaused() external view returns (bool);

    function setPause(bool pause) external;

    function setUsePriceFeeds(
        uint256 _baseFee,
        uint256 _listingFee,
        bool enable
    ) external;

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
