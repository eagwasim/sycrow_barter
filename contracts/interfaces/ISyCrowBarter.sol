// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../enums/ISyCrowBarterType.sol";

interface ISyCrowBarter {
    function factory() external view returns (address);

    function getAmounts() external view returns (uint256, uint256);

    function getTokens() external view returns (address, address);

    function getTrades()
        external
        view
        returns (address[] memory, uint256[] memory, uint256[] memory);

    function tradeTokenForToken(uint256 inAmount) external;

    function tradeTokenForEth(uint256 inAmount) external;

    function tradeEthForToken(uint256 inAmount) external payable;
    
    function totalTradeAmount() external view returns(uint256);

    function allowMultiBarter() external view returns(bool);
    
    function completed() external view returns(bool);

    function deadline() external view returns (uint256);

    function barterType() external view returns (ISyCrowBarterType);

    function withdraw() external;

    function initialize(
        ISyCrowBarterType barterType,
        address inToken,
        address outToken,
        uint256 amountDeposited,
        uint256 amountExpected,
        uint256 deadline,
        bool allowMultiBarter,
        address wethAddress
    ) external returns (bool)
}
