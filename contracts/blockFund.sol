
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract CrowdFunding is ReentrancyGuard{
    event Donation(uint _amount, address _donor);
    event Withdrawal(uint _campaign);
    event Now(uint _thisTime);
    string private _link;
    uint256 public fundingGoal;
    event Refund(address indexed contributor, uint indexed campaignId, uint256 amount);
    event RefundsProcessed(uint indexed campaignId);
    event CampaignEnded(uint indexed campaignId);
    mapping(uint => mapping(address => bool)) public claimedRewards;

    enum CampaignStatus {Active, Expired, GoalReached}

    struct Campaign {
        address owner;
        string title;
        string description;
        uint256 targetAmount;
        uint256 deadline;
        uint256 amountRealised;

    }

    Campaign[] public campaigns;

    // Mapping to keep track of which addresses have contributed to a campaign
    mapping(uint256 => mapping(address=>bool)) public contributedToCampaign;
    
    // Mapping to keep track of all the donors for a campaign
    mapping(uint => address[]) public donors;

    // Fallback function to receive donations
    receive() external payable {
        emit Donation(msg.value, msg.sender);
    }

    // Modifier to check if a campaign exists
    
    modifier campaignExist(uint _id) {
    bool exists = false;
    for (uint i = 0; i < campaigns.length; i++) {
        if (i == _id) {
            exists = true;
            break;
        }
    }
    require(exists, "User does not belong to any campaign");
    _;
    }
    // Add ownership and admin control functions
    modifier onlyAdminOrOwner(uint _id) {
    require(msg.sender == owner || msg.sender == campaigns[_id].owner, "Only admin or owner can perform this action");
    _;
    }

function updateCampaignDetails(uint _id, string memory _title, string memory _description) external onlyAdminOrOwner(_id) {
    campaigns[_id].title = _title;
    campaigns[_id].description = _description;
}

    // Modifier to check if a campaign is active (deadline not reached)
    modifier campaignActive(uint _id){
        require(campaigns[_id].deadline > block.timestamp , "campaign no longer active");
        _;
    }

    // Modifier to check if a campaign has received donations before withdrawing funds
    modifier campaignHasDonations(uint _id){
        require(campaigns[_id].amountRealised > 0, "no donations to withdraw");
        _;
    }

    // Function to create a new campaign
    function createCampaign(string memory _title, string memory  _description, uint256 _target, uint256 _deadline) public returns (bool) {
        require(msg.sender != address(0), "address is not valid");
        require(_deadline > block.timestamp, "The deadline should be a date in the future.");
        campaigns.push(Campaign({
            owner:msg.sender,
            title:_title,
            description:_description,
            targetAmount:_target,
            deadline:_deadline,
            amountRealised:0
        }));

        return true;
    }

    // Function to donate to a campaign
    function donateToCampaign(uint256 _id) public campaignExist(_id) campaignActive(_id) payable {
        emit Now(block.timestamp);
        require(msg.value > 0, "you cannot donate anything less than zero");
        campaigns[_id].amountRealised += msg.value;
        contributedToCampaign[_id][msg.sender] = true;
        donors[_id].push(msg.sender);
    }

    // Function to update the campaign's current funding amount and tracks the contributor's address
    function updateCampaignFund(uint256 _id) external view returns(uint256){
    return campaigns[ _id].amountRealised;
    }

    // Function to get all the donors for a campaign
    function getAllDonors(uint _id) view public campaignExist(_id) returns (address[] memory) {
        return donors[_id];
    }

    // Function to get all the campaigns
    function getAllCampaigns() public view returns (Campaign[] memory) {
        return campaigns;
    }

    // Function to get a particular campaign
    function getAParticularCampaign(uint _id) view public campaignExist(_id) returns(Campaign memory){
       return campaigns[_id];
    }
    // Add a mapping to track claimed rewards


    // Function for investors to claim their rewards
    function claimRewards(uint _id) external campaignExist(_id) {
    require(campaigns[_id].amountRealised >= campaigns[_id].targetAmount, "Campaign not funded");
    require(!claimedRewards[_id][msg.sender], "Rewards already claimed");

    // Perform reward distribution (transfer tokens or perform other actions)
    
    claimedRewards[_id][msg.sender] = true;
    }
    // Function to calculate and return the percentage of funding achieved
    function calculatePercentageFunding(uint _id) external view returns (uint) {
    return (campaigns[_id].amountRealised * 100) / campaigns[_id].targetAmount;
    }

    
    // Function to distribute token rewards
    function distributeTokenRewards(uint _id, uint256 tokenAmount) external campaignExist(_id) onlyOwner {
    require(campaigns[_id].amountRealised >= campaigns[_id].targetAmount, "Campaign not funded");

    // Assuming you have a transfer function in your token contract
    YourTokenContract(tokenAddress).transfer(msg.sender, tokenAmount);
}

    
    // Function to get donors of a campaign
    function getDonors(uint _id) view public campaignActive(_id) returns (address[] memory){
        return donors[_id];
    }
    // Functions that activate appropriate actions if the campaign has ended.
    function endCampaign(uint _id) external campaignExist(_id) {
    require(block.timestamp >= campaigns[_id].deadline, "Campaign has not yet ended");
    
    if (campaigns[_id].amountRealised >= campaigns[_id].targetAmount) {
    } else {
        // Goal was not reached, perform actions such as refunding contributions
        for (uint i = 0; i < donors[_id].length; i++) {
            address contributor = donors[_id][i];
            if (contributedToCampaign[_id][contributor]) {
                uint256 contributionAmount = campaigns[_id].amountRealised / donors[_id].length;
                contributedToCampaign[_id][contributor] = false;
                (bool success, ) = contributor.call{value: contributionAmount}("");
                require(success, "Refund failed");
       
                // Emit refund-related event
                emit Refund(contributor, _id, contributionAmount);
            }
        }
        
        // Update refund status in campaign and donor mappings
        campaigns[_id].amountRealised = 0; 
        donors[_id] = new address[](0); 
        emit RefundsProcessed(_id);

    }

    emit CampaignEnded(_id);
}
    // Function to withdraw donations for a campaign
    function withdrawDonationsForACampain(uint _id) nonReentrant external campaignExist(_id) campaignHasDonations(_id) {
        uint totalAmountDonated = campaigns[_id].amountRealised;
        campaigns[_id].amountRealised = 0;
        (bool success, ) = campaigns[_id].owner.call{value: totalAmountDonated}("");
        require(success, "withdrawal failed");
      

        emit Withdrawal(_id);
    }
}

