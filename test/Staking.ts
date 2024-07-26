import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Staking Contract", function () {
  async function deployStakingFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, addr1, addr2] = await hre.ethers.getSigners();

    const initialSupply = 1000000n * 10n ** 18n; // 1,000,000 tokens with 18 decimals
    const stakeAmount = 1000n * 10n ** 18n; // 1,000 tokens with 18 decimals

    const Token = await hre.ethers.getContractFactory("StakingToken");
    const RewardToken = await hre.ethers.getContractFactory("RewardToken");
    const stakingToken = await Token.deploy(initialSupply);
    const rewardToken = await RewardToken.deploy(initialSupply);

    await stakingToken.waitForDeployment();
    await rewardToken.waitForDeployment();

    const Staking = await hre.ethers.getContractFactory("Staking");
    const staking = await Staking.deploy(
      stakingToken.target,
      rewardToken.target
    );

    await staking.waitForDeployment();

    await stakingToken.approve(staking.target, initialSupply);
    // Transfer tokens to addr1 and addr2 for testing

    await stakingToken.transfer(addr1.getAddress(), stakeAmount);
    await stakingToken.transfer(addr2.getAddress(), stakeAmount);
    await rewardToken.transfer(staking.target, initialSupply);

    return {
      staking,
      stakingToken,
      rewardToken,
      owner,
      addr1,
      addr2,
      stakeAmount,
    };
  }

  describe("Deployment", function () {
    it("Should set the correct reward rate", async function () {
      const { staking } = await loadFixture(deployStakingFixture);
      expect(await staking.rewardRate()).to.equal(1e15);
    });

    it("Should have zero total staked tokens initially", async function () {
      const { staking } = await loadFixture(deployStakingFixture);
      expect(await staking.totalStaked()).to.equal(0);
    });
  });

  describe("Staking", function () {
    it("should allow users to stake tokens", async function () {
      const { staking, stakingToken, addr1, stakeAmount } = await loadFixture(
        deployStakingFixture
      );

      await stakingToken.connect(addr1).approve(staking.target, stakeAmount);
      await staking.connect(addr1).stake(stakeAmount);

      expect(await staking.stakedBalanceOf(await addr1.getAddress())).to.equal(
        stakeAmount
      );
    });

    it("should not allow staking 0 tokens", async function () {
      const { staking, stakingToken, addr1 } = await loadFixture(
        deployStakingFixture
      );

      await stakingToken.connect(addr1).approve(staking.target, 0);
      await expect(
        staking.connect(addr1).stake(0)
      ).to.be.revertedWithCustomError(staking, "AmountMustBeGreaterThanZero");
    });

    it("should update reward balances on staking", async function () {
      const { staking, stakingToken, addr1, stakeAmount } = await loadFixture(
        deployStakingFixture
      );

      await stakingToken.connect(addr1).approve(staking.target, stakeAmount);
      await staking.connect(addr1).stake(stakeAmount);

      // Fast forward time to accumulate rewards
      await time.increase(3600);

      const earned = await staking.earned(await addr1.getAddress());
      expect(earned).to.be.gt(0);
    });
  });

  describe("Withdrawing", function () {
    it("should allow users to withdraw staked tokens", async function () {
      const { staking, stakingToken, addr1, stakeAmount } = await loadFixture(
        deployStakingFixture
      );

      await stakingToken.connect(addr1).approve(staking.target, stakeAmount);
      await staking.connect(addr1).stake(stakeAmount);

      const withdrawAmount = stakeAmount / 2n; // Withdraw half
      await staking.connect(addr1).withdrawStakedTokens(withdrawAmount);
      expect(await staking.stakedBalanceOf(await addr1.getAddress())).to.equal(
        stakeAmount - withdrawAmount
      );
    });

    it("should not allow withdrawing more than staked", async function () {
      const { staking, stakingToken, addr1, stakeAmount } = await loadFixture(
        deployStakingFixture
      );

      await stakingToken.connect(addr1).approve(staking.target, stakeAmount);
      await staking.connect(addr1).stake(stakeAmount);

      const excessiveAmount = stakeAmount + 1n; // More than staked
      await expect(
        staking.connect(addr1).withdrawStakedTokens(excessiveAmount)
      ).to.be.revertedWithCustomError(staking, "AmountNotEnough");
    });
  });

  describe("Rewards", function () {
    it("should allow users to claim rewards", async function () {
      const { staking, stakingToken, rewardToken, addr1, stakeAmount } =
        await loadFixture(deployStakingFixture);

      await stakingToken.connect(addr1).approve(staking.target, stakeAmount);
      await staking.connect(addr1).stake(stakeAmount);

      // Fast forward time to accumulate rewards
      const initialTimestamp = await time.latest();
      await time.increaseTo(initialTimestamp + 3600);

      const earned = await staking.earned(await addr1.getAddress());
      expect(earned).to.be.closeTo(3600n * 1n * 10n ** 15n, 1n * 10n ** 15n); // Use closeTo for slight variations

      await staking.connect(addr1).getReward();
      expect(
        await rewardToken.balanceOf(await addr1.getAddress())
      ).to.be.closeTo(earned, 1n * 10n ** 15n);
    });
  });

  describe("Owner Functions", function () {
    it("should allow owner to pause and unpause the contract", async function () {
      const { staking, owner } = await loadFixture(deployStakingFixture);

      await staking.connect(owner).pause();
      expect(await staking.paused()).to.be.true;

      await staking.connect(owner).unpause();
      expect(await staking.paused()).to.be.false;
    });

    it("should allow owner to update the reward rate", async function () {
      const { staking, owner } = await loadFixture(deployStakingFixture);

      await staking.connect(owner).setRewardRate(2n * 10n ** 15n);
      expect(await staking.rewardRate()).to.equal(2n * 10n ** 15n);
    });
  });


  describe("Emergency Withdrawal", function () {
    it("should allow users to withdraw staked tokens during emergency", async function () {
      const { staking, stakingToken, addr1, stakeAmount,owner } = await loadFixture(deployStakingFixture);

      await stakingToken.connect(addr1).approve(staking.target, stakeAmount);
      await staking.connect(addr1).stake(stakeAmount);

      await staking.connect(owner).pause();
      await staking.connect(addr1).emergencyWithdraw();

      expect(await staking.stakedBalanceOf(await addr1.getAddress())).to.equal(0);
      expect(await stakingToken.balanceOf(await addr1.getAddress())).to.equal(stakeAmount);
    });
  });

});
