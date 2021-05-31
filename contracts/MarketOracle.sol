pragma solidity 0.7.6;

import "./external/SafeMath.sol";

import "./interfaces/IOracle.sol";

import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";

contract MarketOracle is IOracle{
    using SafeMath for uint256;
    uint256 public frequency;

    AggregatorV3Interface internal priceFeed;

    uint256 internal WAD = 10**18;

    uint256 public lastUpdatedTimestamp;
    uint256 public lastUpdatedPrice;    


    constructor(uint256 _frequency, address _aggregator) public {
        frequency = _frequency;
        priceFeed = AggregatorV3Interface(_aggregator);
        update();
    }

    function priceWithValidity() public view override  returns (uint256, bool){
        return (lastUpdatedPrice, block.timestamp - lastUpdatedTimestamp <= frequency);
    }    
    
    function update() public override {
        (
            , 
            int price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        lastUpdatedPrice = uint256(price).mul(WAD).div(10 ** uint256(priceFeed.decimals()));
        lastUpdatedTimestamp = block.timestamp;
    }

    function price() public view  override returns (uint256) {
        require(block.timestamp - lastUpdatedTimestamp <= frequency, "Chainlink Price Feed: Stale Data");
        return lastUpdatedPrice;
    }


}