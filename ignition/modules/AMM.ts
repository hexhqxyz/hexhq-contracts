import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AMMModule = buildModule("AMM", (m) => {
  const stakingTokenAddress = m.getParameter("stakingTokenAddress");
  const rewardTokenAddress = m.getParameter("rewardTokenAddress");

  const AMM = m.contract("AMM", [stakingTokenAddress, rewardTokenAddress]);

  return { AMM };
});

export default AMMModule;
