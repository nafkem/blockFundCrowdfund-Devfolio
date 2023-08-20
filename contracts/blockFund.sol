
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract BlockCrowdFund is ReentrancyGuard{

    //state variables
    uint256 public fundingGoal;
    mapping(uint => mapping(address => bool)) public claimedRewards;
    bool exists;
    address public Admin;
    uint256 public ID;


    //events
    event CampaignCreated(address indexed owner, string indexed campaingTitle, uint256 indexed campaignID);
    event Donation(uint indexed CampaignID, uint256 indexed amount, address indexed donor);
    event UncapturedDonation(uint256 indexed amount, address indexed donor);
    event Withdrawal(uint256 indexed Campaign, address indexed Creator, uint256 indexed amount);

    event Refund(address indexed contributor, uint indexed campaignId, uint256 amount);
    event RefundsProcessed(uint indexed campaignId);
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

    // Modifier to check if a campaign has received donations before withdrawing funds
    modifier campaignHasDonations(uint _campaignID){
        require(campaigns[_campaignID].amountRealised > 0, "No donations");
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
        bool exist;
        bool goalReached;
    }

    Campaign[] public campaigns;

    // Mapping to keep track of which addresses have contributed to a campaign
    mapping(uint256 => mapping(address=>bool)) public contributedToCampaign;
    

    //constructor
    constructor(){
        Admin = msg.sender;
    }




    // Function to create a new campaign
    function createCampaign(string memory _title, string memory  _description, uint256 _target, uint256 _deadline, string memory _ProjectDocumentlink) public returns (bool) {
        require(_target > 0, "Invalid amount");
        uint256 campaignID = ID;
        uint256 campaignDeadline = block.timestamp + _deadline;

        require(campaignDeadline > block.timestamp, "Invalid Deadline");

        campaigns[campaignID].owner = msg.sender;
        campaigns[campaignID].title = _title;
        campaigns[campaignID].description = _description;
        campaigns[campaignID].targetAmount = _target;
        campaigns[campaignID].deadline = campaignDeadline;
        campaigns[campaignID].id = ID;
        campaigns[campaignID].link = _ProjectDocumentlink;
        campaigns[campaignID].exist = true;

        ID++;
        emit CampaignCreated(msg.sender, _title, campaignID);

        return true;
    }

    // Function to donate to a campaign
    function donateToCampaign(uint256 _campaignID) public campaignExist(_campaignID) campaignActive(_campaignID) payable {
        require(msg.value > 0, "Invalid Donation");
        require(campaigns[_campaignID].goalReached == false, "Donations Complete");

        uint256 amountRaised = campaigns[_campaignID].amountRealised + msg.value;

        if(amountRaised >= campaigns[_campaignID].targetAmount){
            campaigns[_campaignID].goalReached = true;
        }
        if(contributedToCampaign[_campaignID][msg.sender] = false){
            contributedToCampaign[_campaignID][msg.sender] = true;
            campaigns[_campaignID].donors.push(msg.sender);

        }

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
      //  require(campaigns[_campaignID].deadline < block.timestamp, "Campaign ON");

        uint totalAmountDonated = campaigns[_campaignID].amountRealised;
        campaigns[_campaignID].amountRealised = 0;
        (bool success, ) = msg.sender.call{value: totalAmountDonated}("");
        require(success, "withdrawal failed");
      
        emit Withdrawal(_campaignID, msg.sender, totalAmountDonated);
    }



    // Function for investors to claim their rewards
    function claimRewards(uint _campaignID) external campaignExist(_campaignID) {
        require(campaigns[_campaignID].amountRealised >= campaigns[_campaignID].targetAmount, "Campaign not funded");
        require(!claimedRewards[_campaignID][msg.sender], "Rewards already claimed");

        // Perform reward distribution (transfer tokens or perform other actions)
        
        claimedRewards[_campaignID][msg.sender] = true;
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
        return campaigns;
    }

    // Function to get a particular campaign
    function getCampaign(uint _campaignID) view public campaignExist(_campaignID) returns(Campaign memory){
       return campaigns[_campaignID];
    }


    // Fallback function to receive donations
    receive() external payable {
        emit UncapturedDonation(msg.value, msg.sender);
    }


}
