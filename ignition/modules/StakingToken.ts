import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StakingTokenModule = buildModule("StakingToken", (m) => {
  const initialSupply = m.getParameter("initialSupply");

  const stakingToken = m.contract("StakingToken", [initialSupply]);

  return { stakingToken };
});

export default StakingTokenModule;
