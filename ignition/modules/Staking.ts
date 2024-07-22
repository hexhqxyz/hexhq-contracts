import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StakingModule = buildModule("Staking", (m) => {
  const stakingTokenAddress = m.getParameter("stakingTokenAddress");
  const rewardTokenAddress = m.getParameter("rewardTokenAddress");

  const staking = m.contract("Staking", [
    stakingTokenAddress,
    rewardTokenAddress,
  ]);

  return { staking };
});

export default StakingModule;
