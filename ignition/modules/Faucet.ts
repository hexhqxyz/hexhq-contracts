import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const FaucetModule = buildModule("Faucet", (m) => {
  const stakingTokenAddress = m.getParameter("stakingTokenAddress");
  const amountAllowed = m.getParameter("amountAllowed");
  const claimInterval = m.getParameter("claimInterval", 10);

  const faucet = m.contract("Faucet", [
    stakingTokenAddress,
    amountAllowed,
    claimInterval
  ]);

  return { faucet };
});

export default FaucetModule;
