import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const RewardTokenModule = buildModule("RewardToken", (m) => {
  const initialSupply = m.getParameter("initialSupply");

  const rewardToken = m.contract("RewardToken", [initialSupply]);

  return { rewardToken };
});

export default RewardTokenModule;
