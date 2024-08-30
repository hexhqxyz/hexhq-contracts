import hre, { ethers } from "hardhat";
import StakingTokenModule from "../ignition/modules/StakingToken";
import RewardTokenModule from "../ignition/modules/RewardToken";
import StakingModule from "../ignition/modules/Staking";
import FaucetModule from "../ignition/modules/Faucet";
import AMMModule from "../ignition/modules/AMM";

const TOKEN_DECIMAL = 18;
async function main() {
  const gasLimit = 500000;
  const initialSupply = 100000; // 1,000,000 tokens
  const faucetFundingAmount = ethers.parseUnits("2000", TOKEN_DECIMAL);
  const faucetAmountAllowedPerPerson = ethers.parseUnits("8", TOKEN_DECIMAL);
  const initialAmmSupply = ethers.parseUnits("5000", TOKEN_DECIMAL);
  const rewardAmount = ethers.parseUnits("10000", TOKEN_DECIMAL);
  const initialStakingApprove = ethers.parseUnits("2000", TOKEN_DECIMAL);

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
        claimInterval: 86400,
      },
    },
  });
  console.log(`Staking deployed to: ${staking.target}`);
  console.log(`Faucet deployed to: ${faucet.target}`);

  const { AMM } = await hre.ignition.deploy(AMMModule, {
    parameters: {
      AMM: {
        stakingTokenAddress: stakingToken.target as string,
        rewardTokenAddress: rewardToken.target as string,
      },
    },
  });

  console.log(`AMM deployed to: ${AMM.target}`);

  await stakingToken.approve(AMM.target, initialAmmSupply);
  await rewardToken.approve(AMM.target, initialAmmSupply);
  console.log("approved initial supply AMM");

  await AMM.provideLiquidity(stakingToken.target, initialAmmSupply, {
    gasLimit: gasLimit,
  });
  console.log("provided initial AMM supply liquidity");

  await stakingToken.approve(staking.target, initialStakingApprove);

  // Transfer some reward tokens to the staking contract
  await rewardToken.transfer(staking.target, rewardAmount);
  await stakingToken.transfer(faucet.target, faucetFundingAmount);

  console.log(
    `Approved staking contract to spend tokens and funded with reward tokens.`
  );
  console.log(`Funded the faucet contract with 1000 tokens.`);
}

main().catch(console.error);
