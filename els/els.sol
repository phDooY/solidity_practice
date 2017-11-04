pragma solidity 0.4.16;

/**
 * TODOs
 * * 0x000 account gets nominated for voting constantly
 * * Can not make a nomination with 1st label created for some reason (mb solidity has problems with 0 index elements???)
 * * Voting throws errors constantly (maybe linked to next point)
 * * How assigned voters supposed to know which nominations they can vote for? securely and privately
 * * To get randomization element from offchain
 * * Save lists of passed nominations label: [users] offchain 
 */

contract owned {
    address public owner;

    function owned()  public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner  public {
        owner = newOwner;
    }
}


contract Congress is owned {
    
    string constant public VERSION = "0.0.3";
    
    // Contract Variables and events
    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    int public majorityMargin;
    Nomination[] public nominations;
    uint public numNominations;
    mapping (address => uint) memberId;
    mapping (uint => address) memberIndex;
    Member[] public members;
    Label[] public labels;
    mapping (string => uint) labelId;


    event NominationAdded(uint nominationID, address recipient, string description);
    event Voted(uint nominationID, bool position, address voter, string justification);
    event NominationTallied(uint nominationID, int result, uint quorum, bool active);
    event LabelAdded(string label, string description);
    event MembershipChanged(address member, bool isMember);
    event ChangeOfRules(uint newMinimumQuorum, uint newDebatingPeriodInMinutes, int newMajorityMargin);
    // debugging [
    event VoterAssigned(uint nominationID, address assignedVoter);
    // debugging ]


    struct Nomination {
        address nominee;
        string label;
        string evidence;
        uint votingDeadline;
        bool executed;
        bool nominationPassed;
        uint numberOfVotes;
        int currentResult;
        bytes32 nominationHash;
        Vote[] votes;
        mapping (address => bool) voted;
        address[] assignedVoters;
        mapping (address => uint) assignedVotersMappig;
    }

    /*
    struct AssignedVoters {
        bytes32 nominationHash;
        address voter;
    }
    */

    struct Label {
        string name;
        string description;
    }
    
    struct Member {
        address member;
        string name;
        uint memberSince;
    }

    struct Vote {
        bool inSupport;
        address voter;
        string justification;
    }
    
    // Modifier that allows only shareholders to vote
    modifier onlyMembers {
        require(memberId[msg.sender] != 0);
        _;
    }

    /**
     * Constructor function
     */
    function Congress (
        uint minimumQuorumForProposals,
        uint minutesForDebate,
        int marginOfVotesForMajority
    )  payable public {
        changeVotingRules(minimumQuorumForProposals, minutesForDebate, marginOfVotesForMajority);
        // It’s necessary to add an empty first member
        addMember(0, "");
        // and let's add the founder, to save a step later
        addMember(owner, 'founder');
    }

    /**
     * Add label
     *
     * @param label Label name
     * @param labelDescription Label description
     */
    function addLabel(string label, string labelDescription) onlyOwner public {
        uint id = labelId[label];
        if (id == 0) {
            labelId[label] = labels.length;
            id = labels.length++;
        }
        
        labels[id] = Label({name: label, description: labelDescription});
        LabelAdded(label, labelDescription);
    }

    /**
     * Add member
     *
     * Make `targetMember` a member named `memberName`
     *
     * @param targetMember ethereum address to be added
     * @param memberName public name for that member
     */
    function addMember(address targetMember, string memberName) onlyOwner public {
        uint id = memberId[targetMember];
        if (id == 0) {
            memberId[targetMember] = members.length;
            id = members.length++;
        }

        members[id] = Member({member: targetMember, memberSince: now, name: memberName});
        MembershipChanged(targetMember, true);
    }

    /**
     * Remove member
     *
     * @notice Remove membership from `targetMember`
     *
     * @param targetMember ethereum address to be removed
     */
    function removeMember(address targetMember) onlyOwner public {
        require(memberId[targetMember] != 0);

        for (uint i = memberId[targetMember]; i<members.length-1; i++){
            members[i] = members[i+1];
        }
        delete members[members.length-1];
        members.length--;
    }

    /**
     * Change voting rules
     *
     * Make so that proposals need tobe discussed for at least `minutesForDebate/60` hours,
     * have at least `minimumQuorumForProposals` votes, and have 50% + `marginOfVotesForMajority` votes to be executed
     *
     * @param minimumQuorumForProposals how many members must vote on a proposal for it to be executed
     * @param minutesForDebate the minimum amount of delay between when a proposal is made and when it can be executed
     * @param marginOfVotesForMajority the proposal needs to have 50% plus this number
     */
    function changeVotingRules(
        uint minimumQuorumForProposals,
        uint minutesForDebate,
        int marginOfVotesForMajority
    ) onlyOwner public {
        minimumQuorum = minimumQuorumForProposals;
        debatingPeriodInMinutes = minutesForDebate;
        majorityMargin = marginOfVotesForMajority;

        ChangeOfRules(minimumQuorum, debatingPeriodInMinutes, majorityMargin);
    }

    /**
     * Add Nomination
     *
     * Propose to send `weiAmount / 1e18` ether to `beneficiary` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param nominee The one being labeled
     * @param evidence Provide some evidence supporting the nomination
     * @param transactionBytecode Bytecode of transaction
     */
    function newNomination(
        address nominee,
        string label,
        string evidence,
        bytes transactionBytecode
    )
        // anyone can nominate anyone
        public returns (uint nominationID)
    {
        require(labelId[label]!=0);            // Only authorized labels allowed, cancel
        require(bytes(evidence).length!=0);       // Does not allow empty evidence, cancel
        nominationID = nominations.length++;
        Nomination storage n = nominations[nominationID];
        n.nominee = nominee;
        n.label = label;
        n.evidence = evidence;
        n.nominationHash = keccak256(nominee, transactionBytecode);
        n.votingDeadline = now + debatingPeriodInMinutes * 1 minutes;
        n.executed = false;
        n.nominationPassed = false;
        n.numberOfVotes = 0;
        NominationAdded(nominationID, nominee, evidence);
        numNominations = nominationID+1;
        
        // 10 randomly selected people should vote on nomination
        var usersToSelect = max(1, i-members.length/10);
        for (uint i=members.length; i>0; i = i - usersToSelect) {
            n.assignedVoters.push(memberIndex[i]);
            n.assignedVotersMappig[memberIndex[i]] = 1;
            
            VoterAssigned(nominationID, memberIndex[i]);
        }
        
        return nominationID;
    }

    function max(uint a, uint b) private returns (uint) {
        return a > b ? a : b;
    }

    /**
     * Check if a nomination code matches
     *
     * @param nominationNumber ID number of the nomination to query
     * @param nominee The one being labeled
     * @param transactionBytecode bytecode of transaction
     */
    function checkNominationCode(
        uint nominationNumber,
        address nominee,
        bytes transactionBytecode
    )
        constant public returns (bool codeChecksOut)
    {
        Nomination storage n = nominations[nominationNumber];
        return n.nominationHash == keccak256(nominee, transactionBytecode);
    }

    /**
     * Log a vote for a nomination
     *
     * Vote `supportsNomination? in support of : against` nomination #`nominationNumber`
     *
     * @param nominationNumber Number of nomination
     * @param supportsNomination Either in favor or against it
     * @param justificationText optional: justification text
     */
    function vote(
        uint nominationNumber,
        bool supportsNomination,
        string justificationText
    )
        onlyMembers public returns (uint voteID)
    {
        Nomination storage n = nominations[nominationNumber];         // Get the proposal
        require(!n.voted[msg.sender]);            // If has already voted, cancel
        require(n.assignedVotersMappig[msg.sender]!=0);   // Only randomly assigned voters can vote, cancel
        n.voted[msg.sender] = true;                     // Set this voter as having voted
        n.numberOfVotes++;                              // Increase the number of votes
        if (supportsNomination) {                         // If they support the proposal
            n.currentResult++;                          // Increase score
        } else {                                        // If they don't
            n.currentResult--;                          // Decrease the score
        }

        // Create a log of this event
        Voted(nominationNumber,  supportsNomination, msg.sender, justificationText);
        return n.numberOfVotes;
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`nominationNumber` and execute it if approved
     *
     * @param nominationNumber Nomination number
     * @param transactionBytecode optional: if the transaction contained a bytecode, you need to send it
     */
    function executeProposal(uint nominationNumber, bytes transactionBytecode) public {
        Nomination storage n = nominations[nominationNumber];

        require(now > n.votingDeadline                                            // If it is past the voting deadline
            && n.nominationHash == keccak256(n.nominee, transactionBytecode)  // and the supplied code matches the proposal
            && n.numberOfVotes >= minimumQuorum);                                  // and a minimum quorum has been reached...

        // ...then execute result

        if (n.currentResult > majorityMargin) {
            // Proposal passed; execute the transaction

            n.executed = true; // Avoid recursive calling
            
            // TODO push to hextable
            
            n.nominationPassed = true;
        } else {
            // Nomination failed
            n.nominationPassed = false;
        }

        // Fire Events
        NominationTallied(nominationNumber, n.currentResult, n.numberOfVotes, n.nominationPassed);
    }
}


