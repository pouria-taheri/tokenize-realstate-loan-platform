// RealEstateDeployer.sol
// SPDX-License-Identifier: MIT

// Real Estate Property Deployer and Verification System
// This contract manages deployment and verification of real estate token contracts

pragma solidity >=0.8.0 <0.9.0;

// AccessControl for role management
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {RealEstateToken} from "./RealEstateToken.sol";

contract RealEstateDeployer is AccessControl {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant LEGAL_ADMIN_ROLE = keccak256("LEGAL_ADMIN_ROLE");

    // Mapping to track which property tokens have been verified

    mapping(RealEstateToken => bool) public verifiedProperties;

    event PropertyTokenized(
        address indexed tokenContract, string propertyAddress, uint256 totalShares, address indexed owner
    );

    event PropertyVerified(address indexed tokenContract, address indexed verifier, uint256 timestamp);

    constructor() {
        // The deployer of this contract becomes the default admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
