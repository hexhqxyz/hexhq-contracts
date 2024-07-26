import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Faucet Contract", function () {
  async function deployFaucetFixture() {
    const [owner, addr1, addr2] = await hre.ethers.getSigners();

    const initialSupply = 1000000n * 10n ** 18n;
    const amountAllowed = 100n * 10n ** 18n;

    const Token = await hre.ethers.getContractFactory("StakingToken");
    const token = await Token.deploy(initialSupply);

    await token.waitForDeployment();

    const Faucet = await hre.ethers.getContractFactory("Faucet");
    const faucet = await Faucet.deploy(token.target, amountAllowed);

    await faucet.waitForDeployment();

    // Transfer some tokens to the faucet contract
    await token.transfer(faucet.target, initialSupply / 2n);

    return { faucet, token, owner, addr1, addr2, amountAllowed, initialSupply };
  }

  describe("Deployment", function () {
    it("Should set the correct token and amount allowed", async function () {
      const { faucet, token, amountAllowed } = await loadFixture(
        deployFaucetFixture
      );
      expect(await faucet.token()).to.equal(token.target);
      expect(await faucet.amountAllowed()).to.equal(amountAllowed);
    });
  });

  describe("Claiming Tokens", function () {
    it("Should allow users to claim tokens", async function () {
      const { faucet, token, addr1, amountAllowed } = await loadFixture(
        deployFaucetFixture
      );

      await faucet.connect(addr1).claimTokens();

      expect(await token.balanceOf(await addr1.getAddress())).to.equal(
        amountAllowed
      );
      expect(await faucet.hasClaimed(await addr1.getAddress())).to.be.true;
    });

    it("Should not allow users to claim tokens more than once", async function () {
      const { faucet, addr1 } = await loadFixture(deployFaucetFixture);

      await faucet.connect(addr1).claimTokens();

      await expect(faucet.connect(addr1).claimTokens()).to.be.revertedWithCustomError(faucet,
        "FaucetAlreadyClaimed"
      );
    });

    it("Should revert if faucet does not have enough tokens", async function () {
      const { faucet, addr1, token, owner } = await loadFixture(
        deployFaucetFixture
      );

      // Empty the faucet using the withdrawTokens function
      const faucetBalance = await token.balanceOf(faucet.target);
      await faucet.connect(owner).withdrawTokens(faucetBalance);

      await expect(faucet.connect(addr1).claimTokens()).to.be.revertedWithCustomError(faucet,
        "FaucetInsufficientFunds"
      );
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to set the amount allowed", async function () {
      const { faucet, owner } = await loadFixture(deployFaucetFixture);

      const newAmountAllowed = 200n * 10n ** 18n;
      await faucet.connect(owner).setAmountAllowed(newAmountAllowed);

      expect(await faucet.amountAllowed()).to.equal(newAmountAllowed);
    });

    it("Should allow owner to withdraw tokens", async function () {
      const { faucet, token, owner, initialSupply } = await loadFixture(
        deployFaucetFixture
      );

      const withdrawAmount = 500n * 10n ** 18n;
      const initialOwnerBalance = await token.balanceOf(owner.getAddress());

      await faucet.connect(owner).withdrawTokens(withdrawAmount);

      const newOwnerBalance = await token.balanceOf(owner.getAddress());
      const faucetBalance = await token.balanceOf(faucet.target);

      expect(newOwnerBalance).to.equal(initialOwnerBalance + withdrawAmount);
      expect(faucetBalance).to.equal(initialSupply / 2n - withdrawAmount);
    });

    it("Should revert if non-owner tries to set amount allowed", async function () {
      const { faucet, addr1 } = await loadFixture(deployFaucetFixture);

      const newAmountAllowed = 200n * 10n ** 18n;
      await expect(
        faucet.connect(addr1).setAmountAllowed(newAmountAllowed)
      ).to.be.revertedWithCustomError(faucet, "OwnableUnauthorizedAccount");
    });

    it("Should revert if non-owner tries to withdraw tokens", async function () {
      const { faucet, addr1 } = await loadFixture(deployFaucetFixture);

      const withdrawAmount = 500n * 10n ** 18n;
      await expect(
        faucet.connect(addr1).withdrawTokens(withdrawAmount)
      ).to.be.revertedWithCustomError(faucet, "OwnableUnauthorizedAccount");
    });
  });
});
