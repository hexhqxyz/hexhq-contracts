// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Automated Market Maker (AMM) Contract
 * @dev Implements a basic AMM with liquidity provision and token swapping functionality.
 */
contract AMM is ReentrancyGuard, Ownable {
    // Custom errors for more efficient error handling
    error AmountMustBeGreaterThanZero();
    error InsufficientLiquidity();
    error InvalidAmounts();
    error InvalidAddress();
    error InvalidReserves();
    error SlippageExceeded();

    // State variables to hold references to the ERC20 tokens
    IERC20 public immutable token1;
    IERC20 public immutable token2;
    uint256 public totalLiquidity;
    uint256 public swapFee;

    // Mappings
    mapping(address => uint256) public liquidity;

    // Events for logging important actions
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

    /**
     * @dev Constructor to initialize the contract with the two ERC20 tokens.
     * @param _token1 Address of the first ERC20 token.
     * @param _token2 Address of the second ERC20 token.
     */
    constructor(address _token1, address _token2) Ownable(msg.sender) {
        if (_token1 == address(0) || _token2 == address(0)) {
            revert InvalidAddress();
        }

        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        swapFee = 1e18; // 1% fee represented as 1e18
    }

    // Modifier to check if the amount is greater than zero
    modifier checkAmount(uint256 amount) {
        if (amount == 0) revert AmountMustBeGreaterThanZero();
        _;
    }

    // Modifier to check if both amounts are greater than zero
    modifier checkAmounts(uint256 amount1, uint256 amount2) {
        if (amount1 == 0 || amount2 == 0) revert AmountMustBeGreaterThanZero();
        _;
    }

    /**
     * @dev Allows users to provide liquidity to the AMM.
     * @param tokenIn Address of the token to be provided.
     * @param amountIn Amount of the token to be provided.
     */
    function provideLiquidity(
        address tokenIn,
        uint256 amountIn
    ) external nonReentrant checkAmount(amountIn) {
        (IERC20 inputToken, IERC20 outputToken) = _getTokenPair(tokenIn);

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
            liquidityMinted = _sqrt(amountIn * amountOut);
        } else {
            liquidityMinted = (amountIn * totalLiquidity) / inputReserve;
        }
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        emit LiquidityProvided(msg.sender, amountIn, amountOut);
    }

    /**
     * @dev Allows users to remove liquidity from the AMM.
     * @param liquidityAmount Amount of liquidity to be removed.
     */
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
     * @param minAmountOut Minimum amount of output tokens expected to receive.
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
        (IERC20 inputToken, IERC20 outputToken) = _getTokenPair(tokenIn);

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

    /**
     * @notice Provides the details of a potential swap.
     * @param tokenIn Address of the token to swap from.
     * @param amountIn Amount of the token to swap.
     * @return amountOut Amount of output tokens received.
     * @return fee Fee charged for the swap.
     * @return newPrice New price after the swap.
     */
    function getSwapDetails(
        address tokenIn,
        uint256 amountIn
    )
        public
        view
        checkAmount(amountIn)
        returns (uint256 amountOut, uint256 fee, uint256 newPrice)
    {
        (IERC20 inputToken, IERC20 outputToken) = _getTokenPair(tokenIn);

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

    /**
     * @notice Returns the liquidity details for a user.
     * @param user Address of the user.
     * @return token1Amount Amount of token1 the user can withdraw.
     * @return token2Amount Amount of token2 the user can withdraw.
     */
    function getUserLiquidity(
        address user
    ) external view returns (uint256 token1Amount, uint256 token2Amount) {
        uint256 userLiquidity = liquidity[user];
        if (userLiquidity == 0) return (0, 0);

        token1Amount =
            (userLiquidity * token1.balanceOf(address(this))) /
            totalLiquidity;
        token2Amount =
            (userLiquidity * token2.balanceOf(address(this))) /
            totalLiquidity;
    }

    /**
     * @notice Calculates the withdrawal amount of liquidity based on a percentage.
     * @param user Address of the user.
     * @param percentInWei Percentage of liquidity to withdraw (in Wei).
     * @return token1Amount Amount of token1 the user can withdraw.
     * @return token2Amount Amount of token2 the user can withdraw.
     */
    function calculateUserLiquidityWithdrawal(
        address user,
        uint256 percentInWei
    ) external view returns (uint256 token1Amount, uint256 token2Amount) {
        uint256 userLiquidity = liquidity[user];
        if (userLiquidity == 0) return (0, 0);

        uint256 liquidityAmount = (userLiquidity * percentInWei) / 1e20;

        token1Amount =
            (liquidityAmount * token1.balanceOf(address(this))) /
            totalLiquidity;
        token2Amount =
            (liquidityAmount * token2.balanceOf(address(this))) /
            totalLiquidity;
    }

    /**
     * @notice Returns the required amount of the other token to provide given an input token amount.
     * @param tokenIn Address of the token to provide.
     * @param amount Amount of the token to provide.
     * @return amountRequired Amount of the other token required.
     */
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

    /**
     * @notice Returns the current prices of the tokens in the AMM.
     * @return priceToken1InToken2 Price of token1 in terms of token2.
     * @return priceToken2InToken1 Price of token2 in terms of token1.
     */
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


    // Internal utility Functions

    /**
     * @notice Returns the token pair for the provided token address.
     * @param tokenIn Address of the input token.
     * @return IERC20, IERC20 The input token and the other token in the pair.
     */
    function _getTokenPair(
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

    /**
     * @notice Calculates the square root of a given number.
     * @param x The number to calculate the square root of.
     * @return y The calculated square root.
     */
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
