import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Tokens", function () {
  async function deployStakingTokenFixture() {
    const [owner, addr1, addr2] = await hre.ethers.getSigners();

    const initialSupply = 1000000n; // 1,000,000 tokens

    const StakingToken = await hre.ethers.getContractFactory("StakingToken");
    const RewardToken = await hre.ethers.getContractFactory("RewardToken");
    const stakingToken = await StakingToken.deploy(initialSupply);
    const rewardToken = await RewardToken.deploy(initialSupply);

    await stakingToken.waitForDeployment(); // Ensure deployment is completed
    await rewardToken.waitForDeployment(); // Ensure deployment is completed

    return { rewardToken, stakingToken, owner, addr1, addr2, initialSupply };
  }

  describe("Deployment", function () {
    it("Should have the correct initial supply", async function () {
      const { stakingToken, owner, initialSupply } = await loadFixture(
        deployStakingTokenFixture
      );
      const ownerBalanceStaking = await stakingToken.balanceOf(
        await owner.getAddress()
      );
      const ownerBalanceReward = await stakingToken.balanceOf(
        await owner.getAddress()
      );
      expect(ownerBalanceStaking).to.equal(initialSupply * 10n ** 18n);
      expect(ownerBalanceReward).to.equal(initialSupply * 10n ** 18n);
    });

    it("Should have the correct name and symbol", async function () {
      const { stakingToken,rewardToken } = await loadFixture(deployStakingTokenFixture);
      expect(await stakingToken.name()).to.equal("OmniDeFi: Staking Token");
      expect(await stakingToken.symbol()).to.equal("DTX");

      expect(await rewardToken.name()).to.equal("OmniDefi: Staking Rewards");
      expect(await rewardToken.symbol()).to.equal("dUSD");
    });
  });

  describe("Transfers", function () {
    it("Should transfer tokens between accounts", async function () {
      const { stakingToken, owner, addr1, initialSupply } = await loadFixture(
        deployStakingTokenFixture
      );

      // Transfer 100 tokens from owner to addr1
      const transferAmount = 100n * 10n ** 18n;
      await stakingToken.transfer(await addr1.getAddress(), transferAmount);

      const addr1Balance = await stakingToken.balanceOf(
        await addr1.getAddress()
      );
      expect(addr1Balance).to.equal(transferAmount);

      const ownerBalance = await stakingToken.balanceOf(
        await owner.getAddress()
      );
      expect(ownerBalance).to.equal(
        initialSupply * 10n ** 18n - transferAmount
      );
    });

    it("Should fail if sender doesn’t have enough tokens", async function () {
      const { stakingToken, addr1, addr2 } = await loadFixture(
        deployStakingTokenFixture
      );

      // Try to send 1 token from addr1 (0 tokens) to addr2 (should fail)
      await expect(
        stakingToken.connect(addr1).transfer(await addr2.getAddress(), 1)
      ).to.be.revertedWithCustomError(stakingToken, "ERC20InsufficientBalance");
    });

    it("Should update balances after transfers", async function () {
      const { stakingToken, owner, addr1, addr2, initialSupply } =
        await loadFixture(deployStakingTokenFixture);

      const transferAmount = 100n * 10n ** 18n;

      // Transfer 100 tokens from owner to addr1
      await stakingToken.transfer(await addr1.getAddress(), transferAmount);

      // Transfer 50 tokens from addr1 to addr2
      await stakingToken
        .connect(addr1)
        .transfer(await addr2.getAddress(), transferAmount / 2n);

      const addr1Balance = await stakingToken.balanceOf(
        await addr1.getAddress()
      );
      expect(addr1Balance).to.equal(transferAmount / 2n);

      const addr2Balance = await stakingToken.balanceOf(
        await addr2.getAddress()
      );
      expect(addr2Balance).to.equal(transferAmount / 2n);

      const ownerBalance = await stakingToken.balanceOf(
        await owner.getAddress()
      );
      expect(ownerBalance).to.equal(
        initialSupply * 10n ** 18n - transferAmount
      );
    });
  });

  describe("Approvals", function () {
    it("Should approve tokens for delegated transfer", async function () {
      const { stakingToken, owner, addr1 } = await loadFixture(
        deployStakingTokenFixture
      );

      const approvalAmount = 100n * 10n ** 18n;
      await stakingToken.approve(await addr1.getAddress(), approvalAmount);

      expect(
        await stakingToken.allowance(
          await owner.getAddress(),
          await addr1.getAddress()
        )
      ).to.equal(approvalAmount);
    });

    it("Should handle delegated token transfers", async function () {
      const { stakingToken, owner, addr1, addr2, initialSupply } =
        await loadFixture(deployStakingTokenFixture);

      const transferAmount = 100n * 10n ** 18n;

      // Owner approves addr1 to spend 100 tokens
      await stakingToken.approve(await addr1.getAddress(), transferAmount);

      // Addr1 transfers 100 tokens from owner to addr2
      await stakingToken
        .connect(addr1)
        .transferFrom(
          await owner.getAddress(),
          await addr2.getAddress(),
          transferAmount
        );

      const addr2Balance = await stakingToken.balanceOf(
        await addr2.getAddress()
      );
      expect(addr2Balance).to.equal(transferAmount);

      const ownerBalance = await stakingToken.balanceOf(
        await owner.getAddress()
      );
      expect(ownerBalance).to.equal(
        initialSupply * 10n ** 18n - transferAmount
      );
    });
  });
});
