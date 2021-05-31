pragma solidity 0.7.6;

interface IOracle {
    function priceWithValidity() external view returns (uint256, bool);
    function update() external;
    function price() external view returns (uint256);
}