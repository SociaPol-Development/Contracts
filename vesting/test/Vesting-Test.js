const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VestingContract", function () {
    let VestingContract, vestingContract, owner, addr1, addr2, token, currentTime;
    const ONE_DAY = 86400;
    const ONE_WEEK = ONE_DAY * 7;
    const ONE_MONTH = ONE_DAY * 30;

    before(async function () {
        const MockToken = await ethers.getContractFactory("MyToken");
        token = await MockToken.deploy();
        await token.deployed();
        console.log("Token deployed to: " +token.address);

        VestingContract = await ethers.getContractFactory("VestingContract");
        [owner, addr1, addr2] = await ethers.getSigners();
        vestingContract = await VestingContract.deploy(token.address);
        await vestingContract.deployed();
        console.log("Vesting Contract deployed to: "+ vestingContract.address);

        const currentBlock = await ethers.provider.getBlock('latest');
        currentTime = currentBlock.timestamp;

        // Owner sends some tokens to the vesting contract
        await token.transfer(vestingContract.address, ethers.utils.parseEther("10000"));
    });

    describe("Vesting Creation", function() {
        it("should create a monthly vesting schedule", async function () {
            const tx1 = await vestingContract.createVestingSchedule(
                addr1.address,
                ethers.utils.parseEther("1000"),
                currentTime - ONE_MONTH,
                currentTime + 11 * ONE_MONTH,
                1
            );
            await tx1.wait();
        });

        it("should batch create vesting schedules", async function () {
            const tx2 = await vestingContract.batchCreateVestingSchedule(
                [addr1.address, addr2.address],
                [ethers.utils.parseEther("1000"), ethers.utils.parseEther("1000")],
                [currentTime - ONE_MONTH, currentTime + ONE_MONTH],
                [currentTime + 11 * ONE_MONTH, currentTime + 12 * ONE_MONTH],
                [1, 1],
                2
            );
            await tx2.wait();
        });
    });

    describe("Claims", function() {
        it("should allow addr1 to claim and have a balance greater than 0", async function () {
            // Send some tokens to the vesting contract
            const tx3 = await token.connect(owner).transfer(vestingContract.address, ethers.utils.parseEther("2000"));
            
            await tx3.wait();

            // Claim for addr1 (should succeed for the first monthly and weekly schedules)
            const tx4 = await vestingContract.connect(addr1).claim();

            await tx4.wait();

            // Check addr1 balance
            const balance = await token.balanceOf(addr1.address);
            expect(balance.toString()).to.not.equal('0');
        });

        it("should claim 0 for addr2", async function () {
            // Claim for addr2 (should not revert but claim 0)
            const tx5 = await vestingContract.connect(addr2).claim();

            await tx5.wait();

            // Check addr2 balance
            const balance = await token.balanceOf(addr2.address);
            expect(balance.toString()).to.equal('0');
        });
    });
});
