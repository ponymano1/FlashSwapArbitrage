// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint reserve0, uint reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC20 {
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}

contract Arbitrage {
    address public factoryA;
    address public factoryB;
    address public token0;
    address public token1;

    constructor(address _factoryA, address _factoryB, address _token0, address _token1) {
        factoryA = _factoryA;
        factoryB = _factoryB;
        token0 = _token0;
        token1 = _token1;
    }

    function startArbitrage(uint amount0, uint amount1) external {
        address pairAddress = IUniswapV2Factory(factoryA).getPair(token0, token1);
        require(pairAddress != address(0), "This pool does not exist");

        IUniswapV2Pair(pairAddress).swap(amount0, amount1, address(this), bytes('not empty'));
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        require(sender == address(this), "Unauthorized");
        require(data.length > 0, "Invalid data");

        // Calculate the amounts for the arbitrage
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        bool isToken0 = balance0 > 0;

        // Perform the swap at the other DEX
        address otherPair = IUniswapV2Factory(factoryB).getPair(token0, token1);
        IERC20(isToken0 ? token0 : token1).approve(otherPair, isToken0 ? balance0 : balance1);
        IUniswapV2Pair(otherPair).swap(isToken0 ? 0 : balance0, isToken0 ? balance1 : 0, address(this), "");

        // Repay the flash swap
        uint fee = ((amount0 + amount1) * 3) / 997 + 1;
        uint amountToRepay = (isToken0 ? amount0 : amount1) + fee;
        IERC20(isToken0 ? token0 : token1).transfer(msg.sender, amountToRepay);
    }

    // In practice, you would also want to include a function to withdraw profits from the contract
}