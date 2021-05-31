pragma solidity 0.7.6;

import "./external/SafeMath.sol";
import "./external/SafeMathInt.sol";
import "./external/Ownable.sol";

import "./external/SafeMathInt.sol";
import "./external/IERC20.sol";

import "./interfaces/IOracle.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./external/UInt256Lib.sol";

interface IUFragments {
    function totalSupply() external view returns (uint256);

    function rebase(uint256 epoch, int256 supplyDelta) external returns (uint256);
}

contract MonetaryPolicy is Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using UInt256Lib for uint256;

    event LogRebase(
        uint256 indexed epoch,
        uint256 currentRate,
        uint256 exchangeRate,
        int256 requestedSupplyAdjustment,
        uint256 timestampSec
    );

    address public pair;
    address public oracle;
    IUFragments public uFrags;
    // More than this much time must pass between rebase operations.
    uint256 public minRebaseTimeIntervalSec;

    // Block timestamp of last rebase operation
    uint256 public lastRebaseTimestampSec;

    // The number of rebase cycles since inception
    uint256 public epoch;

    uint256 private constant DECIMALS = 18;

    uint256 private constant MAX_RATE = 10**6 * 10**DECIMALS;
    // MAX_SUPPLY = MAX_INT256 / MAX_RATE
    uint256 private constant MAX_SUPPLY = uint256(type(int256).max) / MAX_RATE;


    function initialize(
        address owner_, 
        address pair_, 
        address oracle_, 
        address uFrags_
        ) public initializer {
        Ownable.initialize(owner_);
        pair = pair_;
        oracle = oracle_;
        uFrags = IUFragments(uFrags_);
        lastRebaseTimestampSec = 0;
        minRebaseTimeIntervalSec = 21600; // every 6 hours
        epoch = 0;
    }


    function inRebaseWindow() public view returns (bool) {
        return block.timestamp > lastRebaseTimestampSec.add(minRebaseTimeIntervalSec);
    }

    function rebase() external onlyOwner {
        require(inRebaseWindow());
    
        lastRebaseTimestampSec = block.timestamp;
        epoch = epoch.add(1);

        (uint256 currentRate, bool validity) = IOracle(oracle).priceWithValidity();

        require(validity, "Pricefeed data not valid");

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();

        uint256 exchangeRate = IUniswapV2Pair(pair).token0() == address(uFrags) ? reserve0.mul(10**DECIMALS).div(reserve1) : reserve1.mul(10**DECIMALS).div(reserve0);

        if (exchangeRate > MAX_RATE) {
            exchangeRate = MAX_RATE;
        }

        int256 supplyDelta = computeSupplyDelta(exchangeRate, currentRate);


        if (supplyDelta > 0 && uFrags.totalSupply().add(uint256(supplyDelta)) > MAX_SUPPLY) {
            supplyDelta = (MAX_SUPPLY.sub(uFrags.totalSupply())).toInt256Safe();
        }

        uint256 supplyAfterRebase = uFrags.rebase(epoch, supplyDelta);
        assert(supplyAfterRebase <= MAX_SUPPLY);
        emit LogRebase(epoch, currentRate, exchangeRate, supplyDelta, block.timestamp);

    }

    function computeSupplyDelta(uint256 rate, uint256 targetRate) internal view returns (int256) {

        // supplyDelta = totalSupply * (rate - targetRate) / targetRate
        int256 targetRateSigned = targetRate.toInt256Safe();
        return
            uFrags.totalSupply().toInt256Safe().mul(rate.toInt256Safe().sub(targetRateSigned)).div(
                targetRateSigned
            );
    }


}

