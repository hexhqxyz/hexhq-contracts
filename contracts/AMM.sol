// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AMM is ReentrancyGuard, Ownable {
    IERC20 public token1;
    IERC20 public token2;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;
    uint256 public swapFee; // Fee percentage in basis points (100 basis points = 1%)

    event LiquidityProvided(address indexed provider, uint256 indexed amount1, uint256 indexed amount2);
    event LiquidityRemoved(address indexed provider, uint256 indexed amount1, uint256 indexed amount2);
    event Swapped(address indexed swapper, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee);

    constructor(address _token1, address _token2, uint256 _swapFee) Ownable(msg.sender) {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        swapFee = _swapFee;
    }

    function provideLiquidity(uint256 amount1, uint256 amount2) external nonReentrant {
        require(amount1 > 0 && amount2 > 0, "Amounts must be greater than zero");

        uint256 token1Reserve = token1.balanceOf(address(this));
        uint256 token2Reserve = token2.balanceOf(address(this));

        if (totalLiquidity > 0) {
            require(amount1 * token2Reserve == amount2 * token1Reserve, "Provided amounts do not match the pool's current ratio");
        }

        token1.transferFrom(msg.sender, address(this), amount1);
        token2.transferFrom(msg.sender, address(this), amount2);

        uint256 liquidityMinted = (totalLiquidity == 0) ? sqrt(amount1 * amount2) : (amount1 * totalLiquidity) / token1Reserve;
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        emit LiquidityProvided(msg.sender, amount1, amount2);
    }

    function removeLiquidity(uint256 liquidityAmount) external nonReentrant {
        require(liquidity[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        uint256 token1Amount = (liquidityAmount * token1.balanceOf(address(this))) / totalLiquidity;
        uint256 token2Amount = (liquidityAmount * token2.balanceOf(address(this))) / totalLiquidity;

        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        token1.transfer(msg.sender, token1Amount);
        token2.transfer(msg.sender, token2Amount);

        emit LiquidityRemoved(msg.sender, token1Amount, token2Amount);
    }

    function swap(address tokenIn, uint256 amountIn) external nonReentrant returns (uint256 amountOut, uint256 fee) {
        require(amountIn > 0, "Amount must be greater than zero");

        IERC20 inputToken = IERC20(tokenIn);
        IERC20 outputToken = (tokenIn == address(token1)) ? token2 : token1;

        uint256 inputReserve = inputToken.balanceOf(address(this));
        uint256 outputReserve = outputToken.balanceOf(address(this));

        inputToken.transferFrom(msg.sender, address(this), amountIn);

        uint256 inputAmountWithFee = amountIn * (10000 - swapFee) / 10000; // Apply fee
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve * 10000 + inputAmountWithFee;
        amountOut = numerator / denominator;

        outputToken.transfer(msg.sender, amountOut);

        fee = (amountIn * swapFee) / 10000; // Calculate fee
        emit Swapped(msg.sender, tokenIn, address(outputToken), amountIn, amountOut, fee);
    }

    function getSwapDetails(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut, uint256 fee, uint256 newPrice) {
        require(amountIn > 0, "Amount must be greater than zero");

        IERC20 inputToken = IERC20(tokenIn);
        IERC20 outputToken = (tokenIn == address(token1)) ? token2 : token1;

        uint256 inputReserve = inputToken.balanceOf(address(this));
        uint256 outputReserve = outputToken.balanceOf(address(this));

        uint256 inputAmountWithFee = amountIn * (10000 - swapFee) / 10000; // Apply fee
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve * 10000 + inputAmountWithFee;
        amountOut = numerator / denominator;

        fee = (amountIn * swapFee) / 10000; // Calculate fee
        newPrice = (inputReserve + amountIn) / (outputReserve - amountOut); // New price after swap

        return (amountOut, fee, newPrice);
    }

    function getRequiredTokenAmount(uint256 amount1) external view returns (uint256 amount2) {
        require(amount1 > 0, "Amount must be greater than zero");

        uint256 token1Reserve = token1.balanceOf(address(this));
        uint256 token2Reserve = token2.balanceOf(address(this));

        require(token1Reserve > 0 && token2Reserve > 0, "Pool reserves must be greater than zero");

        amount2 = (amount1 * token2Reserve) / token1Reserve;

        return amount2;
    }

    function getCurrentPrices() external view returns (uint256 priceToken1InToken2, uint256 priceToken2InToken1) {
        uint256 token1Reserve = token1.balanceOf(address(this));
        uint256 token2Reserve = token2.balanceOf(address(this));

        require(token1Reserve > 0 && token2Reserve > 0, "Pool reserves must be greater than zero");

        priceToken1InToken2 = (token2Reserve * 1e18) / token1Reserve;
        priceToken2InToken1 = (token1Reserve * 1e18) / token2Reserve;

        return (priceToken1InToken2, priceToken2InToken1);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}