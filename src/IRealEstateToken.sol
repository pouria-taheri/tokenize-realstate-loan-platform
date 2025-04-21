// IRealEstateToken.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IRealEstateToken {
    struct PropertyDetails {
        string propertyAddress;
        string description;
        uint256 totalShares;
        uint256 pricePerShare;
        string propertyDocumentURI;
        bool isRented;
        uint256 yearlyRent;
        uint256 maintenanceFeePercentage;
    }

    struct RentPeriod {
        uint256 startTime;
        uint256 endTime;
        uint256 rentAmount;
        address tenant;
    }

    function getAssetDetails() external view returns (PropertyDetails memory);
    function getRentPeriod(uint256 periodId) external view returns (RentPeriod memory);
}
