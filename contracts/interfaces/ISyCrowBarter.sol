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

    function getTrades()
        external
        view
        returns (address[] memory, uint256[] memory, uint256[] memory);

    function tradeTokenForToken(uint256 inAmount) external;

    function tradeTokenForEth(uint256 inAmount) external;

    function tradeEthForToken(uint256 inAmount) external payable;

    function withdraw() external;
}
