
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC721 {
    function safeMint(address to) external;
    
}

contract FundBlock is ReentrancyGuard{

    //state variables
    uint256 public fundingGoal;
    bool exists;
    address public Admin;
    uint256 public ID;
    address BlockfundNft;


    //events
    event CampaignCreated(address indexed owner, string indexed campaingTitle, uint256 indexed campaignID);
    event Donation(uint indexed CampaignID, uint256 indexed amount, address indexed donor);
    event UncapturedDonation(uint256 indexed amount, address indexed donor);
    event Withdrawal(uint256 indexed CampaignID, address indexed Creator, uint256 indexed amount);
    event Refund(address indexed contributor, uint indexed campaignId, uint256 amount);
    event CampaignEnded(uint indexed campaignId);


    modifier onlyOwner(){
        require(msg.sender == Admin, "Only owner");
        _;
    }

    // Modifier to check if a campaign exists
    modifier campaignExist(uint _campaignID) {
        require(campaigns[_campaignID].exist == true, "Inavlid Campaign");
        _;
    }

    // Add ownership and Creator control functions
    modifier onlyCreator(uint _campaignID) {
        require(msg.sender == campaigns[_campaignID].owner, "Only Creator");
        _;
    }

        // Modifier to check if a campaign is active (deadline not reached)
    modifier campaignActive(uint _campaignID){
        require(campaigns[_campaignID].deadline > block.timestamp , "Inactive Campaign");
        _;
    }

    // Modifier to check if a campaign has reach its goal
    modifier goalReachedCheck(uint _campaignID){
        require(campaigns[_campaignID].goalReached == false, "Donations Complete");
        _;
    }

    //enums
    enum CampaignStatus {Active, Expired, GoalReached}

    //structs
    struct Campaign {
        address owner;
        string title;
        string description;
        uint256 targetAmount;
        uint256 deadline;
        uint256 amountRealised;
        uint256 id;
        string  link;
        address[] donors;
        CampaignStatus status;
        bool exist;
        bool goalReached;
        bool refunded;
        bool withdraw;
    }

  
    mapping(uint256 => Campaign ) campaigns;

    // Mapping to keep track of which addresses have contributed to a campaign
    mapping(uint256 => mapping(address => bool)) public contributedToCampaign;
    mapping(uint256 => mapping(address => bool)) public claimedRewards;
    mapping(address => mapping(uint256 => uint256)) public donorsDetails;

    //constructor
    constructor(address _blockfundNft){
        Admin = msg.sender;
        BlockfundNft = _blockfundNft;
    }


    // Function to create a new campaign
    function createCampaign(string memory _title, string memory  _description, uint256 _target, uint256 _deadline, string memory _ProjectDocumentlink) public returns (uint256) {
        require(_target > 0, "Invalid amount");
        uint256 campaignID = ID;
        ID++;
        uint256 campaignDeadline = block.timestamp + _deadline;

        require(campaignDeadline > block.timestamp, "Invalid Deadline");



        campaigns[campaignID].owner = msg.sender;
        campaigns[campaignID].title = _title;
        campaigns[campaignID].description = _description;
        campaigns[campaignID].targetAmount = _target;
        campaigns[campaignID].deadline = campaignDeadline;
        campaigns[campaignID].id = ID;
        campaigns[campaignID].link = _ProjectDocumentlink;
        campaigns[campaignID].status = CampaignStatus.Active;
        campaigns[campaignID].exist = true;
    

        emit CampaignCreated(msg.sender, _title, campaignID);
        return campaignID;
    }

    // Function to donate to a campaign
    function donateToCampaign(uint256 _campaignID) public campaignExist(_campaignID) campaignActive(_campaignID) goalReachedCheck(_campaignID) payable {
        require(msg.value > 0, "Invalid Donation");

        uint256 amountRaised = campaigns[_campaignID].amountRealised + msg.value;

        if(amountRaised >= campaigns[_campaignID].targetAmount){
            campaigns[_campaignID].goalReached = true;
            campaigns[_campaignID].status = CampaignStatus.GoalReached;
        }

        if(contributedToCampaign[_campaignID][msg.sender] == false){
            contributedToCampaign[_campaignID][msg.sender] = true;
            campaigns[_campaignID].donors.push(msg.sender);
        }
        donorsDetails[msg.sender][_campaignID] += msg.value;
        campaigns[_campaignID].amountRealised += msg.value;
        emit Donation(_campaignID, msg.value, msg.sender);
    }


    //function to update campaign details
    function updateCampaignDetails(uint _campaignID, string memory _description, string memory _ProjectDocumentlink) external campaignActive(_campaignID) onlyCreator(_campaignID) {
        require(campaigns[_campaignID].amountRealised <= 0, "Can't Update");
        campaigns[_campaignID].description = _description;
        campaigns[_campaignID].link = _ProjectDocumentlink;
    }


    // Function to withdraw donations for a campaign
    function withdrawDonationsForACampaign(uint _campaignID) nonReentrant external campaignExist(_campaignID) onlyCreator(_campaignID){
        require(campaigns[_campaignID].goalReached == true, "Didn't reach goal");
        require(campaigns[_campaignID].withdraw == false, "Campaing Funds Claimed");
      //  require(campaigns[_campaignID].deadline < block.timestamp, "Campaign ON");

        uint totalAmountDonated = campaigns[_campaignID].amountRealised;
        campaigns[_campaignID].withdraw = true;
        (bool success, ) = msg.sender.call{value: totalAmountDonated}("");
        require(success, "withdrawal failed");

        campaigns[_campaignID].status = CampaignStatus.Expired;
        
        emit Withdrawal(_campaignID, msg.sender, totalAmountDonated);
    }


    // Functions refund donors
    function refundDonors(uint _campaignID) external campaignExist(_campaignID) goalReachedCheck(_campaignID){
        require(campaigns[_campaignID].deadline < block.timestamp, "Campaign ON");
        require(campaigns[_campaignID].refunded == false, "Already Refunded");

        address[] memory allDonors = campaigns[_campaignID].donors;

        for (uint i = 0; i < allDonors.length; i++) {
              address donors = allDonors[i];

                 uint256 amountDonated = donorsDetails[donors][_campaignID];
                 claimedRewards[_campaignID][donors] = true;
                 donorsDetails[donors][_campaignID] = 0;
                (bool success, ) = donors.call{value: amountDonated}("");
                require(success, "Refund failed");
       
                emit Refund(donors, _campaignID, amountDonated);
            }
        
        campaigns[_campaignID].status = CampaignStatus.Expired;
        campaigns[_campaignID].refunded = true;
        emit CampaignEnded(_campaignID);
    }


    // Function for investors to claim their rewards
    function claimRewards(uint _campaignID) nonReentrant external campaignExist(_campaignID) {
        require(campaigns[_campaignID].goalReached == true, "Goals Not Reached");
        require(!claimedRewards[_campaignID][msg.sender], "Rewards already claimed");
        IERC721(BlockfundNft).safeMint(msg.sender);

        claimedRewards[_campaignID][msg.sender] = true;
    }


    //functions for admin to withdraw lock funds after 70days
    function withdrawLockedFunds(uint256 _campaignID) external onlyOwner{
        require(campaigns[_campaignID].deadline + 6048000 < block.timestamp, "Withdraw Duration");

        uint256 lockedAmount = campaigns[_campaignID].amountRealised;
        (bool success, ) = msg.sender.call{value: lockedAmount}("");
        require(success, "Withdraw failed");
        campaigns[_campaignID].refunded = true;
    }


    function claimRefunds(uint256 _campaignID) external goalReachedCheck(_campaignID){
        require(campaigns[_campaignID].refunded != true, "Already Refunded");
        require(donorsDetails[msg.sender][_campaignID] > 0, "No Refund");
        require(campaigns[_campaignID].deadline < block.timestamp, "Campaign ON");

        uint256 amountDonated = donorsDetails[msg.sender][_campaignID];
        donorsDetails[msg.sender][_campaignID] = 0;

        (bool success, ) = msg.sender.call{value: amountDonated}("");
        require(success, "Refund failed");

        emit Refund(msg.sender, _campaignID, amountDonated);
    }

    
    // Function to get all donors of a campaign
    function getDonors(uint _campaignID) view public campaignExist(_campaignID) returns (address[] memory){
        return campaigns[_campaignID].donors;
    }

        // Function to view the campaign's current funding amount and tracks the contributor's address
    function updateCampaignFund(uint256 _campaignID) external view returns(uint256){
      return campaigns[ _campaignID].amountRealised;
    }

    // Function to check if a user had donate or not
    function donated(uint _campaignID) view public campaignExist(_campaignID) returns (bool) {
        return contributedToCampaign[_campaignID][msg.sender];
    }

    // Function to get all the campaigns
    function getAllCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](ID);

        for(uint i=0; i < ID; i++){
           allCampaigns[i] = campaigns[i];
        }

        return allCampaigns;  
    }

    // Function to get a particular campaign
    function getCampaign(uint _campaignID) view public campaignExist(_campaignID) returns(Campaign memory){
       return campaigns[_campaignID];
    }

    function getCampaignStatus(uint _campaignID) view public campaignExist(_campaignID) returns(CampaignStatus){
        return campaigns[_campaignID].status;
    }


    // Fallback function to receive donations
    receive() external payable {
        emit UncapturedDonation(msg.value, msg.sender);
    }


}


