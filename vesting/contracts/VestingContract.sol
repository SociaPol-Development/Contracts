// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract VestingContract {
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

    struct BeneficiaryData {
        VestingSchedule[] schedules;
        bool isAdded;
    }

    address[] public beneficiaries;
    mapping(address => bool) public isBlackListed;
    mapping(address => BeneficiaryData) public schedules;

    event AddedBlackList(address indexed _user);
    event RemovedBlackList(address indexed _user);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        VestingPeriod period
    );
    event TokensClaimed(address indexed beneficiary, uint256 amount);
    
    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function transferOwnership(address _owner) public onlyOwner {
        require(_owner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, _owner);
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

    function batchAddBlacklist(address[] memory _beneficiaries)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            addBlackList(_beneficiaries[i]);
        }
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        VestingPeriod period
    ) public onlyOwner {
        require(
            endTime > startTime,
            "End time should be greater than start time!"
        );
        uint256 vestingDuration = endTime - startTime;
        uint256 vestingPeriodUnit;
        if (period == VestingPeriod.WEEKLY) {
            vestingPeriodUnit = 1 weeks;
        } else if (period == VestingPeriod.MONTHLY) {
            vestingPeriodUnit = 30 days;
        } else {
            vestingPeriodUnit = vestingDuration;
        }
        require(
            (vestingDuration / vestingPeriodUnit) > 0,
            "Vesting duration is too short for the selected VestingPeriod"
        );

        if (isBlackListed[beneficiary]) {
            return;
        }
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        if (!schedules[beneficiary].isAdded) {
            beneficiaries.push(beneficiary);
            schedules[beneficiary].isAdded = true;
        }

        VestingSchedule memory newSchedule = VestingSchedule({
            beneficiary: beneficiary,
            startTime: startTime,
            endTime: endTime,
            totalAmount: amount,
            claimedAmount: 0,
            period: period
        });

        schedules[beneficiary].schedules.push(newSchedule);

        emit VestingScheduleCreated(
            beneficiary,
            amount,
            startTime,
            endTime,
            period
        );
    }

    function batchCreateVestingSchedule(
        address[] memory _beneficiaries,
        uint256[] memory amounts,
        uint256[] memory startTimes,
        uint256[] memory endTimes,
        VestingPeriod[] memory periods
    ) public onlyOwner {
        require(
            _beneficiaries.length == amounts.length &&
                amounts.length == startTimes.length &&
                startTimes.length == endTimes.length &&
                endTimes.length == periods.length,
            "Input arrays must have the same length"
        );
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            createVestingSchedule(
                _beneficiaries[i],
                amounts[i],
                startTimes[i],
                endTimes[i],
                periods[i]
            );
        }
    }

    function claim() public {
        require(!isBlackListed[msg.sender], "You are blacklisted!");

        BeneficiaryData storage beneficiaryData = schedules[msg.sender];
        uint256 totalClaimed = 0;

        for (uint256 i = 0; i < beneficiaryData.schedules.length; i++) {
            VestingSchedule storage schedule = beneficiaryData.schedules[i];

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
            totalClaimed += payout;
        }

        require(token.transfer(msg.sender, totalClaimed), "Transfer failed");
        emit TokensClaimed(msg.sender, totalClaimed);
    }

    function getVestingSchedule(address _beneficiary)
        public
        view
        returns (VestingSchedule[] memory)
    {
        return schedules[_beneficiary].schedules;
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
            allSchedules[i] = getVestingSchedule(beneficiaries[i]);
        }
        return allSchedules;
    }
}