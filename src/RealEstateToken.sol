//SPDX-License-Identifier: MIT

// RealEstateToken.sol

pragma solidity >=0.8.0 <0.9.0;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "./IRealEstateToken.sol";
import "./RealEstateDeployer.sol";

// @dev A contract for tokenizing real estate properties

contract RealEstateToken is ERC721, ReentrancyGuard, AccessControl, Pausable, IRealEstateToken {
    bytes32 public constant PROPERTY_MANAGER = keccak256("PROPERTY_MANAGER");

    PropertyDetails public propertyDetails;

    mapping(address => bool) public kycApproved; // mapping of kyc approved users
    mapping(uint256 => RentPeriod) public rentPeriods; // mapping of period of rent a home

    mapping(uint256 => uint256) public tokenPrices; // Mapping to store the price of each token

    uint256 public currentRentPeriodId; // counter rent home ID

    // Maintenance reserve
    uint256 public maintenanceReserve;

    address public deployer_;

    event RentDistributed(uint256 totalAmount, uint256 timestamp);
    event MaintenanceFeeDeducted(uint256 amount, string description);
    event KYCStatusUpdated(address indexed user, bool status);
    event PropertyRented(address indexed tenant, uint256 startTime, uint256 endTime, uint256 amount);
    event TokenPurchasedBatch(uint256[] tokenIds, address indexed buyer, uint256 totalPrice);

    //Initializes the NFT and sets up initial property details
    constructor(
        string memory propertyAddress_, //Physical location of the property
        string memory description_, //Description of the property
        //The total number of fractional ownership shares (NFTs) to be created.
        //For example, if totalShares_ = 100, the property is divided into 100 NFTs.
        uint256 totalShares_,
        uint256 pricePerShare_, //Price per share in wei
        string memory propertyDocumentURI_, // property from IPFS or ...
        address admin //The address of the administrator who will have control over key contract functions.
    ) ERC721("Real Estate Token", "RET") {
        // initialize the property details
        propertyDetails = PropertyDetails({
            propertyAddress: propertyAddress_,
            description: description_,
            totalShares: totalShares_,
            pricePerShare: pricePerShare_,
            propertyDocumentURI: propertyDocumentURI_,
            isRented: false,
            yearlyRent: 0,
            maintenanceFeePercentage: 10
        });

        // set up admin roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROPERTY_MANAGER, admin);

        // Approve admin for KYC
        kycApproved[admin] = true;

        // Pre-mint tokens to admin
        for (uint256 i = 0; i < totalShares_; i++) {
            _safeMint(admin, i); // Token IDs start from 0 to totalShares_ - 1
            tokenPrices[i] = pricePerShare_; // Set initial price for each token
        } // property manager = asset manager
    }

    // Modifier to controol access to KYC approved users

    modifier onlyKYCApproved(address user) {
        require(kycApproved[user], "User not KYC approved");
        _;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Update function token ownership with KYC verification
    //* @param to Address receiving the token
    // * @param tokenId Token identifier
    // * @param auth who has access for transfer
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override
        whenNotPaused
        returns (address)
    {
        if (to != address(0)) {
            require(kycApproved[to], "Recipient not KYC approved"); /////////////////////////////////////////////
        }
        return super._update(to, tokenId, auth);
    }

    // set price function only call by property manager
    function setTokenPrice(uint256 tokenId, uint256 price) external onlyRole(PROPERTY_MANAGER) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        require(price > 0, "Price must be greater than zero");
        tokenPrices[tokenId] = price; // Update the price for the token
    }

    // buy fractional of asset we can buy 1 by 1 token
    function purchaseFraction(uint256 tokenId) external payable {
        require(kycApproved[msg.sender], "Buyer not KYC approved");
        uint256 price = tokenPrices[tokenId];
        require(price > 0, "Token not for sale");
        require(msg.value >= price, "Insufficient payment");

        address currentOwner = ownerOf(tokenId);
        require(currentOwner != address(0), "Invalid token owner");

        // Transfer token to buyer
        _transfer(currentOwner, msg.sender, tokenId);

        // Transfer payment to the current owner
        (bool success,) = payable(currentOwner).call{value: msg.value}("");
        require(success, "Payment transfer failed");

        // Clear the price after purchase
        tokenPrices[tokenId] = 0;
    }

    // buy fractional token of asset in batch way it means we can buy 50 token at a time

    function purchaseBatch(uint256[] calldata tokenIds) external payable nonReentrant {
        uint256 totalCost = 0;
        uint256[] memory prices = new uint256[](tokenIds.length);

        // Calculate total cost
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(kycApproved[msg.sender], "Buyer not KYC approved");
            prices[i] = tokenPrices[tokenId];
            require(prices[i] > 0, "Token not for sale");
            address currentOwner = ownerOf(tokenId);
            require(currentOwner != address(0), "Invalid token owner");
            totalCost += prices[i];
        }

        require(msg.value >= totalCost, "Insufficient payment");

        // Refund excess
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        // Process transfers
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address currentOwner = ownerOf(tokenId);
            _transfer(currentOwner, msg.sender, tokenId);
            (bool success,) = currentOwner.call{value: prices[i]}("");
            require(success, "Payment failed");
            tokenPrices[tokenId] = 0;
        }

        emit TokenPurchasedBatch(tokenIds, msg.sender, totalCost);
    }

    // token transfer function with KYC verification
    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        require(to != address(0), "ERC721: transfer to the zero address");
        require(kycApproved[to], "Recipient not KYC approved");

        super._transfer(from, to, tokenId);
        // Deployer(deployer_).tokenTransfer(from, to, tokenId);
    }

    // Safe transfer function with KYC verification
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual override {
        require(kycApproved[to], "Recipient not KYC approved");
        super._safeTransfer(from, to, tokenId, data);
        // Deployer(deployer_).tokenTransfer(from, to, tokenId);
    }

    // manage KYC status of users and only admin can update it

    function setKYCStatus(address user, bool status) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not admin");
        kycApproved[user] = status;
        emit KYCStatusUpdated(user, status);
    }

    // mint new tokens of asset

    function mint(address to, uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) onlyKYCApproved(to) {
        require(tokenId < propertyDetails.totalShares, "Invalid token ID");
        _safeMint(to, tokenId);
    }

    // Sets the yearly rent for asset and only onwer of asset can call it
    function setYearlyRent(uint256 amount) external onlyRole(PROPERTY_MANAGER) {
        propertyDetails.yearlyRent = amount;
    }

    function isKYCApproved(address user) public view returns (bool) {
        return kycApproved[user];
    }

    // users can rent assets
    function rentAsset(uint256 duration) external payable {
        require(!propertyDetails.isRented, "Asset already rented");
        require(msg.value >= propertyDetails.yearlyRent * duration / 365, "Insufficient rent amount");

        propertyDetails.isRented = true;
        uint256 rentPeriodId = currentRentPeriodId++;

        rentPeriods[rentPeriodId] = RentPeriod({
            startTime: block.timestamp,
            endTime: block.timestamp + (duration * 1 days),
            rentAmount: msg.value,
            tenant: msg.sender
        });

        emit PropertyRented(msg.sender, block.timestamp, block.timestamp + (duration * 1 days), msg.value);
    }

    // Distributes rental income money to owners of asset
    function distributeRent(uint256 rentPeriodId) external nonReentrant {
        RentPeriod storage rentPeriod = rentPeriods[rentPeriodId];
        require(rentPeriod.rentAmount > 0, "No rent to distribute");
        require(block.timestamp >= rentPeriod.endTime, "Rent period not ended");

        uint256 maintenanceFee = (rentPeriod.rentAmount * propertyDetails.maintenanceFeePercentage) / 100;
        maintenanceReserve += maintenanceFee;

        uint256 distributionAmount = rentPeriod.rentAmount - maintenanceFee;
        uint256 amountPerShare = distributionAmount / propertyDetails.totalShares;

        for (uint256 i = 0; i < propertyDetails.totalShares; i++) {
            address owner = ownerOf(i);
            (bool success,) = payable(owner).call{value: amountPerShare}("");
            require(success, "Rent distribution failed");
        }

        emit RentDistributed(rentPeriod.rentAmount, block.timestamp);
        delete rentPeriods[rentPeriodId];
    }

    // Maintenance fee management
    // only owner of asset can withdraw maintenance fee
    function withdrawMaintenanceFee(uint256 amount, string calldata description) external onlyRole(PROPERTY_MANAGER) {
        require(amount <= maintenanceReserve, "Insufficient maintenance reserve");
        maintenanceReserve -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Maintenance fee transfer failed");

        emit MaintenanceFeeDeducted(amount, description);
    }

    // Update function the asset documentation URI
    // only admin can update it
    function updatePropertyDocumentURI(string calldata newURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        propertyDetails.propertyDocumentURI = newURI;
    }

    // Only admin can pause and unpause the contract
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    //  Retrieves asset details
    function getAssetDetails() external view returns (PropertyDetails memory) {
        return propertyDetails;
    }

    // Retrieves specific rent period details
    function getRentPeriod(uint256 periodId) external view returns (RentPeriod memory) {
        return rentPeriods[periodId];
    }

    receive() external payable {}

    fallback() external payable {}
}
