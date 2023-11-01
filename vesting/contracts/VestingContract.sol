// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
}

interface IERC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract VestingContract {
    using SafeMath for uint256;

    IERC20 public token;
    address public owner;

    enum VestingPeriod {
        WEEKLY,
        MONTHLY,
        DIRECT
    }

    struct VestingSchedule {
        address beneficiary;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 claimedAmount;
        VestingPeriod period;
    }

    address[] public beneficiaries;

    mapping(address => VestingSchedule[]) public schedules;
    mapping(address => bool) public isBlackListed;

    event AddedBlackList(address indexed _user);
    event RemovedBlackList(address indexed _user);

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function transferOwnership(address _owner) public onlyOwner {
        owner = _owner;
    }

    function addBlackList(address _stakeholder) public onlyOwner {
        isBlackListed[_stakeholder] = true;
        emit AddedBlackList(_stakeholder);
    }

    function removeBlackList(address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    function batchAddBlacklist(
        address[] memory _beneficiaries
    ) public onlyOwner {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            addBlackList(_beneficiaries[i]);
        }
    }

    function setTokenAddress(address _tokenAddress) public onlyOwner {
        token = IERC20(_tokenAddress);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        VestingPeriod period
    ) public onlyOwner {
        if (isBlackListed[beneficiary]) {
            return;
        }
        //require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        beneficiaries.push(beneficiary);

        VestingSchedule memory newSchedule = VestingSchedule({
            beneficiary: beneficiary,
            startTime: startTime,
            endTime: endTime,
            totalAmount: amount,
            claimedAmount: 0,
            period: period
        });

        schedules[beneficiary].push(newSchedule);
    }

    function batchCreateVestingSchedule(
        address[] memory _beneficiaries,
        uint256[] memory amounts,
        uint256[] memory startTimes,
        uint256[] memory endTimes,
        VestingPeriod[] memory periods,
        uint256 batchSize
    ) public onlyOwner {
        for (uint256 i = 0; i < batchSize; i++) {
            address beneficiary = _beneficiaries[i];
            uint256 amount = amounts[i];
            uint256 startTime = startTimes[i];
            uint256 endTime = endTimes[i];
            VestingPeriod period = periods[i];
            createVestingSchedule(
                beneficiary,
                amount,
                startTime,
                endTime,
                period
            );
        }
    }

    function claim() public {
        if (isBlackListed[msg.sender]) {
            return;
        }
        VestingSchedule[] storage beneficiarySchedules = schedules[msg.sender];

        for (uint256 i = 0; i < beneficiarySchedules.length; i++) {
            VestingSchedule storage schedule = beneficiarySchedules[i];

            if (
                block.timestamp < schedule.startTime ||
                block.timestamp > schedule.endTime ||
                schedule.claimedAmount >= schedule.totalAmount
            ) {
                continue;
            }

            uint256 claimableAmount = schedule.totalAmount;
            if (schedule.period != VestingPeriod.DIRECT) {
                uint256 vestingDuration = schedule.endTime - schedule.startTime;
                uint256 timePassed = block.timestamp - schedule.startTime;

                if (schedule.period == VestingPeriod.WEEKLY) {
                    vestingDuration /= 1 weeks;
                    timePassed /= 1 weeks;
                } else if (schedule.period == VestingPeriod.MONTHLY) {
                    vestingDuration /= 30 days;
                    timePassed /= 30 days;
                }

                claimableAmount =
                    (schedule.totalAmount * timePassed) /
                    vestingDuration;
            }

            if (claimableAmount <= schedule.claimedAmount) {
                continue;
            }

            uint256 payout = claimableAmount - schedule.claimedAmount;
            schedule.claimedAmount = claimableAmount;

            require(token.transfer(msg.sender, payout), "Transfer failed");
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner, balance), "Transfer failed");
    }

    function getVestingSchedule(
        address _beneficiary
    ) public view returns (VestingSchedule[] memory) {
        return schedules[_beneficiary];
    }

    function getAllVestingSchedules()
        public
        view
        returns (VestingSchedule[][] memory)
    {
        VestingSchedule[][] memory allSchedules = new VestingSchedule[][](
            beneficiaries.length
        );
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address _beneficiary = beneficiaries[i];
            allSchedules[i] = getVestingSchedule(_beneficiary);
        }
        return allSchedules;
    }
}