const { expect } = require("chai");
const { ethers } = require("hardhat");
const hre = require("hardhat");

describe("LPEth contract", function () {

    let LPEth;
    let stakingPool;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    beforeEach(async function() {
        console.log("start deploy stakingPool ...")
        const stakingPoolFactory = await hre.ethers.getContractFactory("StakingPool");
        stakingPool = await stakingPoolFactory.deploy();
        console.log("stakingPool address is ", stakingPool.address);

        console.log("start deploy LPEth ...")
        const LPEthFactory = await hre.ethers.getContractFactory("LPEth");
        LPEth = await LPEthFactory.deploy(stakingPool.address);
        console.log("LPEth address is ", LPEth.address);

        console.log("init stakingPool ...")
        await stakingPool.init(LPEth.address);

        console.log("deploy success");

        [owner, addr1, addr2, addrs] = await ethers.getSigners();
    });


    describe("Deployment",function () {
        it('stake、withdraw should success', async function () {
            const amount = hre.ethers.utils.parseEther("1");
            await stakingPool.stake(owner.address, { value: amount });

            const ownerBalance1 = await stakingPool.stakedBalance(owner.address);
            expect(ownerBalance1).to.equal("1000000000000000000");

            await stakingPool.withdraw(owner.address);
            const ownerBalance2 = await stakingPool.stakedBalance(owner.address);
            expect(ownerBalance2).to.equal("0");
        });

        it('init、setRewardRatio、setTimeUnit、setMinStakeAmount should only called by owner', async function() {
            await stakingPool.init(LPEth.address);
            // await stakingPool.connect(addr1).init("0x0000000000000000000000000000000000000000");

            await stakingPool.setRewardRatio(1, 20);
            // await stakingPool.connect(addr1).setRewardRatio(1, 1);

            await stakingPool.setTimeUnit(60);
            // await stakingPool.connect(addr1).setTimeUnit(60);

            await stakingPool.setMinStakeAmount(1);
            // await stakingPool.connect(addr1).setMinStakeAmount(1);
        });

        it('getStakeInfo', async function() {
            let stakeInfo = await stakingPool.getStakeInfo(owner.address);
            console.log(stakeInfo);
        });



    });

});
