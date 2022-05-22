// SPDX-License-Identifier: MIT
import "./ISyCrowBarterType.sol";

pragma solidity = 0.8.14;

interface ISyCrowBarterFactory {
    event Creation(
        ISyCrowBarterType barterType,
        address indexed createdBy,
        address indexed barter,
        address inToken,
        address outToken,
        uint256 deadline,
        bool isPrivate
    );

    event Trade(
        address indexed barter,
        address indexed trader,
        uint256 inAmount,
        uint256 outAmount
    );

    event Completion(
        address indexed barter,
        address indexed trader,
        uint256 value1,
        uint256 value2
    );

    function createBarter(
        address inToken,
        address outToken,
        uint256 deposited,
        uint256 expected,
        uint256 deadline,
        ISyCrowBarterType barterType,
        bool allowMultiBarter,
        bool isPrivate
    ) external payable returns (address barter);

    function totalBarterDeployed() external returns (uint256);

    function getFee() external returns (uint256);

    function setFeeCollector(address _feeCollector) external;

    function feeCollector() external view returns (address);

    function allBartersLength() external view returns (uint256);

    function allBarters(uint256) external view returns (address barter);

    function getUserBarters(address userAddress)
        external
        view
        returns (address[] memory barters);

    function getUserBartersLength(address userAddress)
        external
        view
        returns (uint256);

    function getUserBarter(address userAddress, uint256 index)
        external
        view
        returns (address);

    function isPaused() external view returns (bool);

    function setPause(bool pause) external;

    function setUsePriceFeeds(
        uint256 _baseFee,
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
