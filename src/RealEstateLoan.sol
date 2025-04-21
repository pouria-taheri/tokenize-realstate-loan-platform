// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./RealEstateToken.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract RealEstateLoan is ReentrancyGuard, Pausable, AccessControl, IERC721Receiver {
    bytes32 public constant LOAN_MANAGER = keccak256("LOAN_MANAGER");

    struct Loan {
        address borrower;
        uint256[] collateralTokenIds;
        uint256 loanAmount;
        uint256 interestRate; // Annual interest rate with 2 decimal places ( 850 = 8.50%)
        uint256 startTime;
        uint256 duration; // Duration in days
        uint256 totalRepaid;
        bool isActive;
        bool isLiquidated;
    }

    struct LoanProposal {
        address borrower;
        uint256[] collateralTokenIds;
        uint256 requestedAmount;
        uint256 proposedDuration; // in days
        bool isActive;
    }

    // Contract state variables
    RealEstateToken public realEstateToken;
    mapping(uint256 => Loan) public loans; // loanId => Loan
    mapping(uint256 => LoanProposal) public proposals; // proposalId => LoanProposal
    mapping(uint256 => bool) public tokenLocked; // tokenId => isLocked
    mapping(uint256 => uint256) public proposalToLoanId;

    uint256 public nextLoanId;
    uint256 public nextProposalId;
    uint256 public minimumCollateralRatio = 150; // 150% collateral required
    uint256 public liquidationThreshold = 130; // Liquidate if collateral ratio falls below 130%

    // Events
    event LoanProposed(uint256 indexed proposalId, address indexed borrower, uint256 requestedAmount);
    event LoanApproved(uint256 indexed loanId, uint256 indexed proposalId, uint256 amount, uint256 interestRate);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event LoanLiquidated(uint256 indexed loanId, address indexed borrower);
    event CollateralReleased(uint256 indexed loanId, address indexed borrower);

    // constructor(address _realEstateToken) {
    //     realEstateToken = IERC721(_realEstateToken);
    //     _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    //     _grantRole(LOAN_MANAGER, msg.sender);
    // }

    constructor(address _realEstateToken) {
        realEstateToken = RealEstateToken(payable(_realEstateToken));
        // realEstateToken.setKYCStatus(address(this), true);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LOAN_MANAGER, msg.sender);
    }

    // Propose a new loan
    function proposeLoan(uint256[] calldata tokenIds, uint256 requestedAmount, uint256 duration)
        external
        whenNotPaused
    {
        require(duration >= 7 days && duration <= 365 days, "Invalid loan duration");
        require(requestedAmount > 0, "Invalid loan amount");

        // Verify token ownership and approve status
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(realEstateToken.ownerOf(tokenIds[i]) == msg.sender, "Not token owner");
            require(!tokenLocked[tokenIds[i]], "Token already locked");
        }

        uint256 proposalId = nextProposalId++;
        proposals[proposalId] = LoanProposal({
            borrower: msg.sender,
            collateralTokenIds: tokenIds,
            requestedAmount: requestedAmount,
            proposedDuration: duration,
            isActive: true
        });

        emit LoanProposed(proposalId, msg.sender, requestedAmount);
    }

    // Approve and fund a loan proposal
    function approveLoan(uint256 proposalId, uint256 interestRate)
        external
        payable
        onlyRole(LOAN_MANAGER)
        nonReentrant
    {
        LoanProposal storage proposal = proposals[proposalId];
        require(proposal.isActive, "Proposal not active");
        require(msg.value >= proposal.requestedAmount, "Insufficient loan amount");

        // Transfer collateral tokens to contract
        for (uint256 i = 0; i < proposal.collateralTokenIds.length; i++) {
            uint256 tokenId = proposal.collateralTokenIds[i];
            realEstateToken.safeTransferFrom(proposal.borrower, address(this), tokenId);
            tokenLocked[tokenId] = true;
        }

        // Create loan
        uint256 loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: proposal.borrower,
            collateralTokenIds: proposal.collateralTokenIds,
            loanAmount: proposal.requestedAmount,
            interestRate: interestRate,
            startTime: block.timestamp,
            duration: proposal.proposedDuration,
            totalRepaid: 0,
            isActive: true,
            isLiquidated: false
        });

        proposalToLoanId[proposalId] = loanId;

        // Transfer loan amount to borrower
        (bool success,) = payable(proposal.borrower).call{value: proposal.requestedAmount}("");
        require(success, "Loan transfer failed");

        // Deactivate proposal
        proposal.isActive = false;

        emit LoanApproved(loanId, proposalId, proposal.requestedAmount, interestRate);
    }

    // Calculate total amount due for a loan
    function calculateTotalDue(uint256 loanId) public view returns (uint256) {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");

        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.loanAmount * loan.interestRate * timeElapsed) / (365 days * 10000);
        return loan.loanAmount + interest - loan.totalRepaid;
    }

    // Make a loan repayment
    function repayLoan(uint256 loanId) external payable nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive && !loan.isLiquidated, "Loan not active");
        require(msg.value > 0, "Invalid repayment amount");

        uint256 totalDue = calculateTotalDue(loanId);
        uint256 payment = msg.value > totalDue ? totalDue : msg.value;
        loan.totalRepaid += payment;

        // Check if loan is fully repaid
        if (loan.totalRepaid >= calculateTotalDue(loanId)) {
            _releaseLoanCollateral(loanId);
        }

        // Refund excess payment if any
        if (msg.value > payment) {
            (bool success,) = payable(msg.sender).call{value: msg.value - payment}("");
            require(success, "Refund transfer failed");
        }

        emit LoanRepaid(loanId, payment);
    }

    // Release collateral after full repayment
    function _releaseLoanCollateral(uint256 loanId) internal {
        Loan storage loan = loans[loanId];

        // Transfer all collateral tokens back to borrower
        for (uint256 i = 0; i < loan.collateralTokenIds.length; i++) {
            uint256 tokenId = loan.collateralTokenIds[i];
            tokenLocked[tokenId] = false;
            realEstateToken.safeTransferFrom(address(this), loan.borrower, tokenId);
        }

        loan.isActive = false;
        emit CollateralReleased(loanId, loan.borrower);
    }

    // Liquidate defaulted loan
    function liquidateLoan(uint256 loanId) external onlyRole(LOAN_MANAGER) nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive && !loan.isLiquidated, "Invalid loan status");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not yet defaulted");
        // better check require 
        // require(block.timestamp > loan.startTime + (loan.duration * 1 days), "..."); 
        
        loan.isActive = false;
        loan.isLiquidated = true;

        // Transfer collateral tokens to loan manager
        for (uint256 i = 0; i < loan.collateralTokenIds.length; i++) {
            uint256 tokenId = loan.collateralTokenIds[i];
            tokenLocked[tokenId] = false;
            realEstateToken.safeTransferFrom(address(this), msg.sender, tokenId);
        }

        emit LoanLiquidated(loanId, loan.borrower);
    }

    function getProposal(uint256 proposalId) public view returns (address, uint256[] memory, uint256, uint256, bool) {
        LoanProposal storage proposal = proposals[proposalId];
        return (
            proposal.borrower,
            proposal.collateralTokenIds,
            proposal.requestedAmount,
            proposal.proposedDuration,
            proposal.isActive
        );
    }

    function getLoanDetails(uint256 loanId)
        public
        view
        returns (address, uint256[] memory, uint256, uint256, uint256, uint256, uint256, bool, bool)
    {
        Loan storage loan = loans[loanId];
        return (
            loan.borrower,
            loan.collateralTokenIds,
            loan.loanAmount,
            loan.interestRate,
            loan.startTime,
            loan.duration,
            loan.totalRepaid,
            loan.isActive,
            loan.isLiquidated
        );
    }

    // Required for IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // Emergency pause
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    receive() external payable {}
    fallback() external payable {}
}
