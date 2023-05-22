// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

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
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    modifier isRegistered() {
        require(voters[msg.sender].isRegistered, "You're not registered !");
        _;
    }

    modifier canVote() {
        require(!voters[msg.sender].hasVoted, "You're already voted !");
        require(status == WorkflowStatus.VotingSessionStarted, "You can't vote for proposal at this time");
        _;
    }

    modifier checkWorkflowStatus(WorkflowStatus _status) {
        require(status == _status, "You can't do this for now");
        _;
    }

    constructor() {
        status = WorkflowStatus.RegisteringVoters;
    }

    function startProposalsRegistration() public onlyOwner checkWorkflowStatus(WorkflowStatus.RegisteringVoters) {
        WorkflowStatus previousStatus = status;
        status = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(previousStatus, status);
    }

    function endProposalsRegistration() public onlyOwner checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        WorkflowStatus previousStatus = status;
        status = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(previousStatus, status);
    }

    function startVotingSession() public onlyOwner checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationEnded) {
        WorkflowStatus previousStatus = status;
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(previousStatus, status);
    }

    function endVotingSession() public onlyOwner checkWorkflowStatus(WorkflowStatus.VotingSessionStarted) {
        WorkflowStatus previousStatus = status;
        status = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(previousStatus, status);
    }

    function countVotes() public onlyOwner checkWorkflowStatus(WorkflowStatus.VotingSessionEnded){
        uint maxVotesNumber = 0;
        for (uint i=0; i < proposals.length; i++) {
            if (maxVotesNumber < proposals[i].voteCount) {
                maxVotesNumber = proposals[i].voteCount;
                winningProposalId = i;
            }
        }

        WorkflowStatus previousStatus = status;
        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(previousStatus, status);
    }

    function register(address _address) public onlyOwner checkWorkflowStatus(WorkflowStatus.RegisteringVoters) {
        require(!voters[_address].isRegistered, "Already registered !");

        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    function registerProposal(string memory _description) public isRegistered checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length-1);
    }

    function voteForProposal(uint _proposalId) public isRegistered canVote {
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;

        emit Voted (msg.sender, _proposalId);
    }

    function getWinner() public checkWorkflowStatus(WorkflowStatus.VotesTallied) view returns(Proposal memory) {
        return proposals[winningProposalId];
    }
}
