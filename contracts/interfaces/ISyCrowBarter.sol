// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

enum ISyCrowBarterType {
    ETH_FOR_TOKEN,
    TOKEN_FOR_ETH,
    TOKEN_FOR_TOKEN
}

interface ISyCrowBarter {
    function factory() external view returns (address);

    function getAmounts() external view returns (uint256, uint256);

    function getTokens() external view returns (address, address);

    function getBarterBalance() external view returns (uint256);

    function getDeadline() external view returns (uint256);

    function getBarterType() external view returns (ISyCrowBarterType);

    function getTrades()
        external
        view
        returns (address[] memory, uint256[] memory);

    function tradeTokenForToken(uint256 inAmount) external;

    function tradeTokenForEth(uint256 inAmount) external payable;

    function tradeEthForToken(uint256 inAmount) external payable;

    function tradeTokenForToken() external;

    function tradeTokenForEth() external payable;

    function tradeEthForToken() external payable;

    function withdraw() external;

    function withdraw(address _erc20TokenAddress) external view;
}
