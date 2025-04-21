// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {Test, console, Vm} from "../lib/forge-std/src/Test.sol";
import {RealEstateLoan} from "../src/RealEstateLoan.sol";
import "../src/RealEstateToken.sol";
import {DeployRealEstate} from "../script/DeployRealEstateToken.s.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract TestRealEstateToken is Test, IERC721Receiver {
    RealEstateToken public token;
    DeployRealEstate public deployer;
    RealEstateLoan public loan;

    address public admin;
    address public user1;
    address public user2;
    address public propertyManager;
    address public loanManager;

    // Test Configuraion

    string constant propertyAddress = "123 Main St";
    string constant description = "2 bedroom apartment";
    uint256 constant totalShares = 100; //
    uint256 constant pricePerShare = 1 ether;
    string constant propertyURI = "ipfs://QmExample...";

    // events

    event KYCStatusUpdated(address indexed user, bool status);
    event propertyRented(address indexed tenat, uint256 startTime, uint256 endTime, uint256 amount);
    event rentDistributed(uint256 totalAmount, uint256 timestamp);
    event maintenanceFeeDeducted(uint256 amount, string description);
    event LoanProposed(uint256 indexed proposalId, address indexed borrower, uint256 requestedAmount);
    event LoanApproved(uint256 indexed loanId, uint256 indexed proposalId, uint256 amount, uint256 interestRate);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);

    receive() external payable {}

    function setUp() public {
        admin = address(this);
        // user1 = address(0x01);
        // user2 = address(0x02);
        user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        propertyManager = address(0x03);
        loanManager = address(0x04);

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(loanManager, 100 ether);

        token = new RealEstateToken("123 Main St", "A beautiful property", 100, 1 ether, "ipfs://property-doc", admin);

        // deployer = new DeployRealEstate();
        // deployer.run();
        loan = new RealEstateLoan(address(token));

        loan.grantRole(loan.LOAN_MANAGER(), loanManager);
    }

    function testInitialKYCStatus() public {
        // Check initial KYC status of user1 and user2
        bool user1KYCStatus = token.isKYCApproved(user1);
        bool user2KYCStatus = token.isKYCApproved(user2);

        assertFalse(user1KYCStatus, "User1 should not be KYC approved initially");
        assertFalse(user2KYCStatus, "User2 should not be KYC approved initially");
    }

    // KYC Tests
    function testSetKYCStatus() public {
        vm.expectEmit(true, true, false, true);
        emit KYCStatusUpdated(user1, true);

        token.setKYCStatus(user1, true);
        assertTrue(token.kycApproved(user1));
    }

    function testFailSetKYCStatusUnauthorized() public {
        vm.prank(user1);
        token.setKYCStatus(user2, true);
    }

    function testTokenTransfer() public {
        // Approve KYC for user1
        token.setKYCStatus(user1, true);

        // Transfer token 0 to user1
        token.transferFrom(admin, user1, 0);
        assertEq(token.ownerOf(0), user1);
    }

    function testPurchaseFraction() public {
        // Initial balance check
        uint256 initialSellerBalance = address(this).balance;
        uint256 initialBuyerBalance = user1.balance;

        // Setup
        token.setKYCStatus(user1, true);
        token.setTokenPrice(0, 1 ether);

        // Purchase
        vm.prank(user1);
        token.purchaseFraction{value: 1 ether}(0);

        // Verify token ownership
        assertEq(token.ownerOf(0), user1);

        // Verify balances changed correctly
        assertEq(address(this).balance, initialSellerBalance + 1 ether);
        assertEq(user1.balance, initialBuyerBalance - 1 ether);

        // Verify price was reset
        assertEq(token.tokenPrices(0), 0);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function testFailPurchaseInsufficientPayment() public {
        token.setKYCStatus(user1, true);
        token.setTokenPrice(0, 1 ether);

        vm.prank(user1);
        token.purchaseFraction{value: 0.5 ether}(0);
    }

    function testPauseUnpause() public {
        token.pause();
        assertTrue(token.paused());

        token.unpause();
        assertFalse(token.paused());
    }

    function testFailTransferWhenPaused() public {
        token.setKYCStatus(user1, true);
        token.pause();

        vm.expectRevert("ERC721Pausable: token transfer while paused");
        token.transferFrom(admin, user1, 0);
    }

    function testFuzz_SetTokenPrice(uint256 price) public {
        vm.assume(price > 0 && price < 1000 ether);

        token.setTokenPrice(0, price);
        assertEq(token.tokenPrices(0), price);
    }

    ////////////////////// LOAN TESTING///////////////////////////

    function testLoanProposal() public {
        // Setup
        token.setKYCStatus(user1, true);
        token.transferFrom(admin, user1, 0); // Transfer token 0 to user1

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.startPrank(user1);
        token.approve(address(loan), 0);

        vm.expectEmit(true, true, false, true);
        emit LoanProposed(0, user1, 1 ether);

        loan.proposeLoan(tokenIds, 1 ether, 30 days);
        vm.stopPrank();

        // Verify proposal
        (address borrower,,, bool isActive) = loan.proposals(0);
        assertEq(borrower, user1);
        assertTrue(isActive);
    }

    function testMultiTokenLoanProposal() public {
        token.setKYCStatus(user1, true);

        token.transferFrom(admin, user1, 0);
        token.transferFrom(admin, user1, 1);
        token.transferFrom(admin, user1, 2);

        vm.startPrank(user1);
        token.approve(address(loan), 0);
        token.approve(address(loan), 1);
        token.approve(address(loan), 2);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        vm.expectEmit(true, true, false, true);
        emit LoanProposed(0, user1, 3 ether);
        loan.proposeLoan(tokenIds, 3 ether, 30 days);
        vm.stopPrank();

        // Retrieve the proposal using the explicit getter
        (
            address borrower,
            uint256[] memory collateralTokenIds,
            uint256 requestedAmount,
            uint256 proposedDuration,
            bool isActive
        ) = loan.getProposal(0);

        assertEq(borrower, user1);
        assertEq(collateralTokenIds.length, 3);
        assertEq(requestedAmount, 3 ether);
        assertEq(proposedDuration, 30 days);
        assertTrue(isActive);
    }

    function testApproveLoan() public {
        // Approve user1 for KYC
        token.setKYCStatus(user1, true);

        token.setKYCStatus(address(loan), true);

        // Transfer token to user1
        token.transferFrom(admin, user1, 0);

        // Propose a loan
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.startPrank(user1);
        token.approve(address(loan), 0);
        loan.proposeLoan(tokenIds, 1 ether, 30 days);
        vm.stopPrank();

        // Get the proposal ID (nextProposalId - 1)
        uint256 proposalId = loan.nextProposalId() - 1;

        // Approve the loan
        vm.startPrank(loanManager);
        loan.approveLoan{value: 1 ether}(proposalId, 850); // 8.50% interest rate
        vm.stopPrank();

        // Get the loan ID from the proposalToLoanId mapping
        uint256 loanId = loan.proposalToLoanId(proposalId);

        // Use the getter function to access loan details
        (
            address borrower,
            uint256[] memory collateralTokenIds,
            uint256 loanAmount,
            uint256 interestRate,
            uint256 startTime,
            uint256 duration,
            uint256 totalRepaid,
            bool isActive,
            bool isLiquidated
        ) = loan.getLoanDetails(loanId);

        // Verify loan details
        assertEq(borrower, user1, "Borrower should be user1");
        assertEq(collateralTokenIds.length, 1, "Collateral should have 1 token");
        assertEq(collateralTokenIds[0], 0, "Collateral token ID should be 0");
        assertEq(loanAmount, 1 ether, "Loan amount should be 1 ether");
        assertEq(interestRate, 850, "Interest rate should be 8.50%");
        assertGe(startTime, block.timestamp - 1, "Start time should be set");
        assertEq(duration, 30 days, "Duration should be 30 days");
        assertEq(totalRepaid, 0, "Total repaid should be 0");
        assertTrue(isActive, "Loan should be active");
        assertFalse(isLiquidated, "Loan should not be liquidated");

        // Verify token ownership
        assertEq(token.ownerOf(0), address(loan), "Token should be transferred to loan contract");
    }

    function testLoanRepayment() public {
        // Setup and approve loan
        testApproveLoan();

        // Get the loan ID from the proposalToLoanId mapping
        uint256 loanId = loan.proposalToLoanId(0); // Use the proposal ID (0) to get the loan ID

        // Advance time by 15 days
        vm.warp(block.timestamp + 15 days);

        // Calculate and make repayment
        uint256 totalDue = loan.calculateTotalDue(loanId);

        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit LoanRepaid(loanId, totalDue);

        loan.repayLoan{value: totalDue}(loanId);
        vm.stopPrank();

        // Verify loan is closed and collateral returned
        (
            address borrower,
            uint256[] memory collateralTokenIds,
            uint256 loanAmount,
            uint256 interestRate,
            uint256 startTime,
            uint256 duration,
            uint256 totalRepaid,
            bool isActive,
            bool isLiquidated
        ) = loan.getLoanDetails(loanId); // Use the loanId variable

        // Assert loan details
        assertEq(borrower, user1, "Borrower should be user1");
        assertEq(collateralTokenIds.length, 1, "Collateral should have 1 token");
        assertEq(collateralTokenIds[0], 0, "Collateral token ID should be 0");
        assertEq(loanAmount, 1 ether, "Loan amount should be 1 ether");
        assertEq(interestRate, 850, "Interest rate should be 8.50%");
        assertGe(startTime, block.timestamp - 15 days - 1, "Start time should be set");
        assertEq(duration, 30 days, "Duration should be 30 days");
        assertEq(totalRepaid, totalDue, "Total repaid should match the repayment amount");
        assertFalse(isActive, "Loan should not be active after repayment");
        assertFalse(isLiquidated, "Loan should not be liquidated");
    }

    function testFailInvalidLoanDuration() public {
        token.setKYCStatus(user1, true);
        token.transferFrom(admin, user1, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.startPrank(user1);
        token.approve(address(loan), 0);
        loan.proposeLoan(tokenIds, 1 ether, 5 days); // Duration too short
        vm.stopPrank();
    }

    function testFailUnauthorizedLoanApproval() public {
        // Setup loan proposal
        testLoanProposal();

        // Try to approve loan from non-manager account
        vm.prank(user2);
        loan.approveLoan{value: 1 ether}(0, 850);
    }

    function testLoanLiquidation() public {
        // Setup and approve loan
        testApproveLoan();

        // Approve the loan manager for KYC
        token.setKYCStatus(loanManager, true);

        // Advance time beyond loan duration
        vm.warp(block.timestamp + 31 days);

        vm.prank(loanManager);
        loan.liquidateLoan(0);
        uint256 loanId = loan.proposalToLoanId(0);

        (
            address borrower,
            uint256[] memory collateralTokenIds,
            uint256 loanAmount,
            uint256 interestRate,
            uint256 startTime,
            uint256 duration,
            uint256 totalRepaid,
            bool isActive,
            bool isLiquidated
        ) = loan.getLoanDetails(loanId);

        assertFalse(isActive);
        assertTrue(isLiquidated);
        assertEq(token.ownerOf(0), loanManager); // Token transferred to loan manager
    }

    function testFailEarlyLiquidation() public {
        // Setup and approve loan
        testApproveLoan();

        // Try to liquidate before loan duration ends
        vm.prank(loanManager);
        loan.liquidateLoan(0);
    }
}
