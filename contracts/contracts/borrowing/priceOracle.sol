pragma solidity 0.8.0;

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string memory _base, string memory _quote)
        external
        view
        returns (ReferenceData memory);

    /// Similar to getReferenceData, but with multiple base/quote pairs at once.
    function getReferenceDataBulk(string[] memory _bases, string[] memory _quotes)
        external
        view
        returns (ReferenceData[] memory);
}

/**
 * @title Price Feed Oracle
 */
contract priceOracle {

    IStdReference public ref;
    address public priceFeedAddress;

    // 0xDA7a001b254CD22e46d3eAB04d937489c93174C3 Mainnet
    // Alfajores: 0x71046b955Cdd96bC54aCa5E66fd69cfb5780f3BB
    constructor() {
        priceFeedAddress = 0xDA7a001b254CD22e46d3eAB04d937489c93174C3;
         ref = IStdReference(priceFeedAddress);
    }

    function getPrice() external view returns (uint256){
        IStdReference.ReferenceData memory data = ref.getReferenceData("CELO","USD");
        return data.rate;
    }
}
