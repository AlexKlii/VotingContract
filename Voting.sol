// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/**
 * @title Voting
 * @dev Implements voting process
 */
contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    mapping(address => Voter) voters;

    struct Proposal {
        string description;
        uint voteCount;
    }
    Proposal[] proposals;
    uint winningProposalId = 0;

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
    WorkflowStatus status;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus,WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // modifier to check if caller is a registered voter
    modifier isRegistered() {
        require(voters[msg.sender].isRegistered, "You're not registered !");
        _;
    }

    // modifier to check if caller can vote for a proposal
    modifier canVote() {
        require(!voters[msg.sender].hasVoted, "You're already voted !");
        require(status == WorkflowStatus.VotingSessionStarted, "You can't vote for proposal at this time");
        _;
    }

    // modifier to check if the action is called during the good period 
    modifier checkWorkflowStatus(WorkflowStatus _status) {
        require(status == _status, "You can't do this for now");
        _;
    }

    constructor() {
        status = WorkflowStatus.RegisteringVoters;
    }

    /**
     * @dev Update the current status
     * @param _newStatus new status
     * @param _requiredStatus the required status to perform this action
     */
    function _updateStatus(WorkflowStatus _newStatus,WorkflowStatus _requiredStatus) private onlyOwner checkWorkflowStatus(_requiredStatus) {
        WorkflowStatus previousStatus = status;
        status = _newStatus;
        emit WorkflowStatusChange(previousStatus, status);
    }

    /**
     * @dev Start Proposals Registration
     */
    function startProposalsRegistration() public {
        _updateStatus(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.RegisteringVoters
        );
    }

    /**
     * @dev End Proposals Registration
     */
    function endProposalsRegistration() public {
        _updateStatus(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    /**
     * @dev Start Voting Session
     */
    function startVotingSession() public {
        _updateStatus(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    /**
     * @dev End Voting Session
     */
    function endVotingSession() public {
        _updateStatus(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    /**
     * @dev Determine the winner and update the workflow status to "Votes Counted"
     */
    function countVotes() public onlyOwner checkWorkflowStatus(WorkflowStatus.VotingSessionEnded) {
        uint maxVotesNumber = 0;
        for (uint i = 0; i < proposals.length; i++) {
            if (maxVotesNumber < proposals[i].voteCount) {
                maxVotesNumber = proposals[i].voteCount;
                winningProposalId = i;
            // If a proposal has the same number of votes as the actual winner, we determine a "random" winner among these two proposals
            // /!\ Warning: it's not completely random but for this specific case, it will be more than enough.
            } else if (maxVotesNumber == proposals[i].voteCount) {
                uint rand = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, i))) % 100;
                if (rand >= 50) {
                    winningProposalId = i;
                }
            }
        }

        _updateStatus(
            WorkflowStatus.VotesTallied,
            WorkflowStatus.VotingSessionEnded
        );
    }

    /**
     * @dev Register an address as a Voter
     * @param _address Address to register
     */
    function register(address _address) public onlyOwner checkWorkflowStatus(WorkflowStatus.RegisteringVoters) {
        require(!voters[_address].isRegistered, "Already registered !");

        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    /**
     * @dev Register a new proposal
     * @param _description Description of the proposal
     */
    function registerProposal(string memory _description) public isRegistered checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        require(bytes(_description).length > 10, "Proposal description must contain at least 10 characters");
        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length - 1);
    }

    /**
     * @dev Registered voters can vote for a proposal
     * @param _proposalId Proposal id
     */
    function voteForProposal(uint _proposalId) public isRegistered canVote {
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    /**
     * @dev Retrieve the voted proposal id for a specific voter
     * @param _addr Voter address
     */
    function votedProposalId(address _addr) public view isRegistered returns (uint) {
        require(voters[_addr].hasVoted, "This voter didn't vote for any proposal");
        return voters[_addr].votedProposalId;
    }

    /**
     * @dev Retrieve the winning proposal
     */
    function getWinner() public view checkWorkflowStatus(WorkflowStatus.VotesTallied) returns (Proposal memory) {
        return proposals[winningProposalId];
    }

    /**
     * @dev Retrieve all proposals
     */
    function getProposals() public view isRegistered returns (Proposal[] memory) {
        return proposals;
    }
}
