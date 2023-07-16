// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


contract CrowdFunding {
    struct Campaign {
        address owner;
        string title;
        string description;
        uint256 target;
        // uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(address => bool) public isAlerted;
    mapping(address => bool) public isDepositor;
    mapping(address => bool) public isWithdrawal;
    uint256 public numberOfCampaigns = 0;
    uint256 public threshold;
    address public charitableOrganization;
    string public alertText = " ";

    event SuspiciousDonation(address indexed account, uint256 amount, string alertMessage);
    event MoneyLaunderingAlert(address indexed account);
    event LogMessage(string message);

    modifier onlyCharitableOrganization() {
        require(msg.sender == charitableOrganization, "Only charitable organization can perform this action");
        _;
    }

    constructor() {
        charitableOrganization = msg.sender;
        threshold = 10 ether;
    }

    function setThreshold(uint256 _threshold) external onlyCharitableOrganization {
        threshold = _threshold;
    }

    function createCampaign(address _owner, string memory _title, string memory _description, uint256 _target, string memory _image) public returns (uint256) {
        Campaign storage campaign = campaigns[numberOfCampaigns];

        // require(_deadline > block.timestamp, "The deadline should be a date in the future.");

        campaign.owner = _owner;
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        // campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;

        numberOfCampaigns++;

        return numberOfCampaigns - 1;
    }

    function getAlertText() public view returns (string memory) {
        return alertText;
    }

    function donateToCampaign(uint256 _id) public payable {
        uint256 amount = msg.value;
        string memory alertMessage;
        bool isAlert = false;

        Campaign storage campaign = campaigns[_id];

        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);

        if (amount > threshold && amount < 50 ether) {
            alertMessage = string(abi.encodePacked("Huge transaction Alert: You (", addressToString(msg.sender), ") transferred ", uint256ToString(amount)));
            emit SuspiciousDonation(msg.sender, amount, alertMessage);
            isAlerted[msg.sender] = true;

            isAlert = true;
        } else {
            alertMessage = "Normal Transaction";
        }

        if (address(this).balance >= 50 ether || amount >= 50 ether) {
            alertMessage = string(abi.encodePacked("Money Laundering Alert: Your (", addressToString(msg.sender), ") will be considered as money laundering as you are trying to transfer more than 50 eth"));
            emit SuspiciousDonation(msg.sender, amount, alertMessage);
            isAlerted[msg.sender] = true;

            isAlert = true;
        } else {
            alertMessage = "Normal Transaction";
        }

        (bool sent,) = payable(campaign.owner).call{value: amount}("");

        if (sent) {
            campaign.amountCollected = campaign.amountCollected + amount;
            isDepositor[msg.sender] = true;
        }

        alertText = alertMessage;
    }

    function withdrawFromCampaign(uint256 _id, uint256 amount) external {
        Campaign storage campaign = campaigns[_id];

        require(amount <= campaign.amountCollected, "Insufficient funds in the campaign");

        (bool sent,) = payable(msg.sender).call{value: amount}("");

        if (sent) {
            campaign.amountCollected = campaign.amountCollected - amount;
            isWithdrawal[msg.sender] = true;
            if (address(this).balance > 50 ether) {
                checkMoneyLaundering(campaign);
            }
        }
    }

    function checkMoneyLaundering(Campaign storage campaign) internal {
        for (uint256 i = 0; i < campaign.donators.length; i++) {
            if (isDepositor[campaign.donators[i]] && !isAlerted[campaign.donators[i]]) {
                emit MoneyLaunderingAlert(campaign.donators[i]);
                isAlerted[campaign.donators[i]] = true;
            }
        }

        for (uint256 i = 0; i < campaign.donators.length; i++) {
            if (isWithdrawal[campaign.donators[i]] && !isAlerted[campaign.donators[i]]) {
                emit MoneyLaunderingAlert(campaign.donators[i]);
                isAlerted[campaign.donators[i]] = true;
            }
        }
    }

    function getDonators(uint256 _id) public view returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](numberOfCampaigns);

        for(uint i = 0; i < numberOfCampaigns; i++) {
            Campaign storage item = campaigns[i];

            allCampaigns[i] = item;
        }

        return allCampaigns;
    }

    function getAddressAlertStatus(address _address) public view returns (bool) {
        return isAlerted[_address];
    }

    function getAllAlertedAddresses() public view returns (address[] memory) {
    uint256 count = 0;
    for (uint256 i = 0; i < numberOfCampaigns; i++) {
        if (isAlerted[campaigns[i].owner]) {
            count++;
        }
        for (uint256 j = 0; j < campaigns[i].donators.length; j++) {
            if (isAlerted[campaigns[i].donators[j]]) {
                count++;
            }
        }
    }

    address[] memory alertedAddresses = new address[](count);
    uint256 index = 0;

    for (uint256 i = 0; i < numberOfCampaigns; i++) {
        if (isAlerted[campaigns[i].owner]) {
            alertedAddresses[index] = campaigns[i].owner;
            index++;
        }
        for (uint256 j = 0; j < campaigns[i].donators.length; j++) {
            if (isAlerted[campaigns[i].donators[j]]) {
                alertedAddresses[index] = campaigns[i].donators[j];
                index++;
            }
        }
    }

    return alertedAddresses;
}


    function addressToString(address _address) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_address)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function uint256ToString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }
        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }
        return string(buffer);
    }
}
