// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import "../src/RealEstateDeployer.sol";
import "../src/RealEstateToken.sol";
import "../src/RealEstateLoan.sol";

contract DeployRealEstate is Script {
    function run() external {
        // Retrieve private key from environment variable
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the RealEstateDeployer first
        RealEstateDeployer realEstateDeployer = new RealEstateDeployer();

        // Example parameters for a property token
        string memory propertyAddress = "123 Main St";
        string memory description = "2 bedroom apartment";
        uint256 totalShares = 100;

        uint256 pricePerShare = 1 ether; // 1 ETH per share
        string memory propertyDocumentURI = "ipfs://QmExample...";

        // Deploy RealEstateToken
        RealEstateToken token = new RealEstateToken(
            propertyAddress,
            description,
            totalShares,
            pricePerShare,
            propertyDocumentURI,
            deployer // Set deployer as admin
        );

        // Approve KYC for the deployer/admin address
        token.setKYCStatus(deployer, true);
        RealEstateLoan loan = new RealEstateLoan(address(token));


        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log the deployed addresses
        console.log("RealEstateDeployer deployed at:", address(realEstateDeployer));
        console.log("RealEstateToken deployed at:", address(token));
        console.log("Deployer/Admin address:", deployer);
    }
}
