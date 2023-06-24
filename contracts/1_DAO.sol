// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Main {
    struct Proposal {
        uint256 id;
        string description;
        uint256 amount;
        address payable recipient;
        uint256 votes;
        uint256 endAt;
        bool isExecuted;
    }

    mapping(address => bool) public isInvestor;
    address[] public investorsList;
    mapping(address => uint256) public numOfShares;
    mapping(address => mapping(uint256 => bool)) public isVoted;
    // mapping(address => mapping(address => bool)) public withdrawlStats;
    mapping(uint256 => Proposal) public proposals;

    uint256 public totalShares;
    uint256 public availableFunds;
    uint256 contributionTimeEnd;
    uint256 public nextProposalId;
    uint256 voteTime;
    uint256 quorum;
    address manager;

    constructor(
        uint256 _contributionTimeEnd,
        uint256 _voteTime,
        uint256 _quorum
    ) {
        require(_quorum > 0 && _quorum < 100, "Invalid quorum value!");
        contributionTimeEnd = block.timestamp + _contributionTimeEnd * 60;
        voteTime = _voteTime * 60;
        quorum = _quorum;
        manager = msg.sender;
    }

    modifier onlyInvestor() {
        require(isInvestor[msg.sender], "You are not Investor");
        _;
    }

    modifier onlyManager() {
        require(manager == msg.sender, "You are not Manager");
        _;
    }

    function contribute() public payable {
        require(
            block.timestamp <= contributionTimeEnd,
            "Contribution time ended"
        );
        require(msg.value > 0, "Invalid amount");
        isInvestor[msg.sender] = true;
        numOfShares[msg.sender] += msg.value;
        totalShares += msg.value;
        availableFunds += msg.value;
        investorsList.push(msg.sender);
    }

    function redeem(uint256 amount) public onlyInvestor {
        require(numOfShares[msg.sender] >= amount, "Not contributed enough!");
        require(availableFunds >= amount, "Not enough funds left");
        payable(msg.sender).transfer(amount);
        totalShares -= amount;
        availableFunds -= amount;
        numOfShares[msg.sender] -= amount;
        if (numOfShares[msg.sender] == 0) isInvestor[msg.sender] = false;
    }

    function transferShares(uint256 amount, address to) public onlyInvestor {
        require(numOfShares[msg.sender] >= amount, "Not contributed enough!");
        numOfShares[msg.sender] -= amount;
        if (numOfShares[msg.sender] == 0) isInvestor[msg.sender] = false;
        isInvestor[to] = true;
        investorsList.push(to);
        numOfShares[to] += amount;
    }

    function createProposal(
        string calldata description,
        uint256 amount,
        address payable recipient
    ) public onlyManager {
        require(availableFunds >= amount, "Not enough funds left");
        proposals[nextProposalId] = Proposal(
            nextProposalId,
            description,
            amount,
            recipient,
            0,
            block.timestamp + voteTime,
            false
        );
        nextProposalId++;
    }

    function voteProposal(uint256 proposalId) public onlyInvestor {
        require(isVoted[msg.sender][proposalId] == false, "Already voted!");
        Proposal storage proposal = proposals[proposalId]; //create pointer proposal -> improves readibility
        require(proposal.endAt >= block.timestamp, "Voting time over!");
        require(proposal.isExecuted == false, "Proposal already executed");
        isVoted[msg.sender][proposalId] == true;
        proposal.votes += numOfShares[msg.sender];
    }

    function executeProposal(uint256 proposalId) public onlyManager {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.endAt < block.timestamp, "Voting not over!");
        require((proposal.votes * 100) / totalShares >= quorum, "No Majority");
        require(proposal.isExecuted == false, "Proposal already executed");
        require(availableFunds >= proposal.amount, "Not enough funds");
        payable(proposal.recipient).transfer(proposal.amount);
        proposal.isExecuted = true;
        availableFunds -= proposal.amount;
        totalShares -= proposal.amount;
    }

    function proposalList() public view returns (Proposal[] memory) {
        Proposal[] memory prr = new Proposal[](nextProposalId);
        for (uint256 i; i < nextProposalId; i++) {
            prr[i] = proposals[i];
        }
        return prr;
    }
}
