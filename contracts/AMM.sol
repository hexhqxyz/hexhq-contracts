// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AMM is ReentrancyGuard, Ownable {
    error AmountMustBeGreaterThanZero();
    error InsufficientLiquidity();
    error InvalidAmounts();
    error InvalidAddress();
    error InvalidReserves();
    error SlippageExceeded();

    IERC20 public token1;
    IERC20 public token2;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;
    uint256 public swapFee;

    event LiquidityProvided(
        address indexed provider,
        uint256 indexed amount1,
        uint256 indexed amount2
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 indexed amount1,
        uint256 indexed amount2
    );
    event Swapped(
        address indexed swapper,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _token1, address _token2) Ownable(msg.sender) {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        swapFee = 1e18; // 1% fee represented as 1e18
    }

    modifier checkAmount(uint256 amount) {
        if (amount <= 0) revert AmountMustBeGreaterThanZero();
        _;
    }

    modifier checkAmounts(uint256 amount1, uint256 amount2) {
        if (amount1 <= 0 || amount2 <= 0) revert AmountMustBeGreaterThanZero();
        _;
    }

    function provideLiquidity(
        address tokenIn,
        uint256 amountIn
    ) external nonReentrant checkAmount(amountIn) {
        (IERC20 inputToken, IERC20 outputToken) = getTokenPair(tokenIn);

        uint256 inputReserve = inputToken.balanceOf(address(this));
        uint256 outputReserve = outputToken.balanceOf(address(this));

        uint256 amountOut;
        if (inputReserve == 0 || outputReserve == 0) {
            amountOut = amountIn; // In initial state, assume equal value
        } else {
            amountOut = getRequiredTokenAmount(tokenIn, amountIn);
        }

        // Transfer tokens to the contract
        inputToken.transferFrom(msg.sender, address(this), amountIn);
        outputToken.transferFrom(msg.sender, address(this), amountOut);

        uint256 liquidityMinted;
        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(amountIn * amountOut);
        } else {
            liquidityMinted = (amountIn * totalLiquidity) / inputReserve;
        }
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        emit LiquidityProvided(msg.sender, amountIn, amountOut);
    }

    function removeLiquidity(
        uint256 liquidityAmount
    ) external nonReentrant checkAmount(liquidityAmount) {
        if (liquidity[msg.sender] < liquidityAmount)
            revert InsufficientLiquidity();

        uint256 token1Amount = (liquidityAmount *
            token1.balanceOf(address(this))) / totalLiquidity;
        uint256 token2Amount = (liquidityAmount *
            token2.balanceOf(address(this))) / totalLiquidity;

        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        token1.transfer(msg.sender, token1Amount);
        token2.transfer(msg.sender, token2Amount);

        emit LiquidityRemoved(msg.sender, token1Amount, token2Amount);
    }

    /**
     * @notice Swaps tokens in this contract between two tokens (token1 and token2).
     * @dev The amount of input tokens must be greater than zero.
     * @param tokenIn Address of the ERC20 token to swap from. It should be either `address(token1)` or `address(token2)`.
     * @param amountIn Amount of input tokens to swap.
     * @return amountOut Returns the amount of output tokens received.
     * @return fee Returns the fee charged for this swap.
     */
    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        nonReentrant
        checkAmounts(amountIn, minAmountOut)
        returns (uint256 amountOut, uint256 fee)
    {
        if (minAmountOut > amountIn) revert InvalidAmounts();
        (amountOut, fee, ) = getSwapDetails(tokenIn, amountIn);
        if (amountOut < minAmountOut) revert SlippageExceeded();
        (IERC20 inputToken, IERC20 outputToken) = getTokenPair(tokenIn);

        inputToken.transferFrom(msg.sender, address(this), amountIn);
        outputToken.transfer(msg.sender, amountOut);

        emit Swapped(
            msg.sender,
            tokenIn,
            address(outputToken),
            amountIn,
            amountOut
        );
    }

    function getSwapDetails(
        address tokenIn,
        uint256 amountIn
    )
        public
        view
        checkAmount(amountIn)
        returns (uint256 amountOut, uint256 fee, uint256 newPrice)
    {
        (IERC20 inputToken, IERC20 outputToken) = getTokenPair(tokenIn);

        uint256 inputReserve = inputToken.balanceOf(address(this));
        uint256 outputReserve = outputToken.balanceOf(address(this));

        fee = (amountIn * swapFee) / 1e20; // Calculate fee as a percentage
        uint256 inputAmountWithFee = amountIn - fee; // Apply fee
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve + inputAmountWithFee;
        amountOut = numerator / denominator;

        uint256 newInputReserve = inputReserve + amountIn;
        uint256 newOutputReserve = outputReserve - amountOut;
        newPrice = (newInputReserve * 1e18) / newOutputReserve; // New price after swap

        return (amountOut, fee, newPrice);
    }

    function getRequiredTokenAmount(
        address tokenIn,
        uint256 amount
    ) public view checkAmount(amount) returns (uint256 amountRequired) {
        uint256 token1Reserve = token1.balanceOf(address(this));
        uint256 token2Reserve = token2.balanceOf(address(this));

        if (token1Reserve <= 0 || token2Reserve <= 0) revert InvalidReserves();

        if (tokenIn == address(token1)) {
            amountRequired = (amount * token2Reserve) / token1Reserve;
        } else {
            amountRequired = (amount * token1Reserve) / token2Reserve;
        }
        return amountRequired;
    }

    function getCurrentPrices()
        external
        view
        returns (uint256 priceToken1InToken2, uint256 priceToken2InToken1)
    {
        uint256 token1Reserve = token1.balanceOf(address(this));
        uint256 token2Reserve = token2.balanceOf(address(this));

        if (token1Reserve <= 0 || token2Reserve <= 0) revert InvalidReserves();

        priceToken1InToken2 = (token2Reserve * 1e18) / token1Reserve;
        priceToken2InToken1 = (token1Reserve * 1e18) / token2Reserve;

        return (priceToken1InToken2, priceToken2InToken1);
    }

    function getTokenPair(
        address tokenIn
    ) internal view returns (IERC20, IERC20) {
        if (tokenIn == address(token1)) {
            return (token1, token2);
        } else if (tokenIn == address(token2)) {
            return (token2, token1);
        } else {
            revert InvalidAddress();
        }
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
