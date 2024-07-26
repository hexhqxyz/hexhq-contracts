import hre, { ethers } from "hardhat";
import StakingTokenModule from "../ignition/modules/StakingToken";
import RewardTokenModule from "../ignition/modules/RewardToken";
import StakingModule from "../ignition/modules/Staking";
import FaucetModule from "../ignition/modules/Faucet";
import AMMModule from "../ignition/modules/AMM";

async function main() {
  const initialSupply = 100000; // 1,000,000 tokens
  const faucetFundingAmount = ethers.parseUnits("1000", 18);
  const faucetAmountAllowedPerPerson = ethers.parseUnits("7", 18);
  const initialAmmSupply = ethers.parseUnits("5000", 18);
  const rewardAmount = ethers.parseUnits("10000", 18);
  const initialStakingApprove = ethers.parseUnits("2000", 18);

  const { stakingToken } = await hre.ignition.deploy(StakingTokenModule, {
    parameters: { StakingToken: { initialSupply: initialSupply } },
  });
  const { rewardToken } = await hre.ignition.deploy(RewardTokenModule, {
    parameters: { RewardToken: { initialSupply: initialSupply } },
  });

  console.log(`Staking Token deployed to: ${stakingToken.target}`);
  console.log(`Reward Token deployed to: ${rewardToken.target}`);
  const { staking } = await hre.ignition.deploy(StakingModule, {
    parameters: {
      Staking: {
        stakingTokenAddress: stakingToken.target as string,
        rewardTokenAddress: rewardToken.target as string,
      },
    },
  });

  const { faucet } = await hre.ignition.deploy(FaucetModule, {
    parameters: {
      Faucet: {
        stakingTokenAddress: stakingToken.target as string,
        amountAllowed: faucetAmountAllowedPerPerson,
        claimInterval: 10,
      },
    },
  });
  console.log(`Staking deployed to: ${staking.target}`);
  console.log(`Faucet deployed to: ${faucet.target}`);

  const { AMM } = await hre.ignition.deploy(AMMModule, {
    parameters: {
      Staking: {
        stakingTokenAddress: stakingToken.target as string,
        rewardTokenAddress: rewardToken.target as string,
      },
    },
  });

  console.log(`AMM deployed to: ${AMM.target}`);

  await stakingToken.approve(AMM.target, initialAmmSupply);
  await rewardToken.approve(AMM.target, initialAmmSupply);
  console.log("approved initial supply AMM");

  await AMM.provideLiquidity(initialAmmSupply, initialAmmSupply);
  console.log("provided initial AMM supply liquidity");

  await stakingToken.approve(staking.target, initialStakingApprove);

  // Transfer some reward tokens to the staking contract
  await rewardToken.transfer(staking.target, rewardAmount);
  await stakingToken.transfer(faucet.target, faucetFundingAmount);

  console.log(
    `Approved staking contract to spend tokens and funded with reward tokens.`
  );
  console.log(
    `Funded the faucet contract with ${ethers.formatUnits(
      faucetFundingAmount,
      18
    )} tokens.`
  );
}

main().catch(console.error);
