// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "./v2-periphery/interfaces/IUniswapV2Router02.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * @title 闪电贷套利
 * @author 
 * @notice 
 * 借tokenA 还tokenB
 * 或者借tokenB 还tokenA
 * 注意点:借tokenA时，回调中还tokenA和tokenB都可以，只要最后满足 x*y == k的公式就行   
 * 
 */
contract FlashSwapArbitrage is IUniswapV2Callee{
    address immutable internal _factoryA;
    address immutable internal _factoryB;
    address immutable internal _uniswapRouterA;
    address immutable internal _uniswapRouterB;
    address internal _tokenA;
    address internal _tokenB;
    address internal _owner;//利润打给owner


    constructor(address factoryA, address factoryB, address tokenA, address tokenB, address uniswapRouterA, address uniswapRouterB, address owner) {
        _factoryA = factoryA;
        _factoryB = factoryB;
        _tokenA = tokenA;
        _tokenB = tokenB;
        _uniswapRouterA = uniswapRouterA;
        _uniswapRouterB = uniswapRouterB;
        _owner = owner;
    }
    

    /**
     * @param tokenBorrow 需要借出的token
     * @param amount 需要借出的数量
     * 
     */
    function startArbitrage(address tokenBorrow, uint256 amount) external {
        address pair1 = IUniswapV2Factory(_factoryA).getPair(_tokenA, _tokenB);
        require(pair1 != address(0), 'FlashSwap: Invalid pair');
        bytes memory data = abi.encode(tokenBorrow, amount);
        address token0 = IUniswapV2Pair(pair1).token0();
        address token1 = IUniswapV2Pair(pair1).token1();
        uint256 amountOut0 = tokenBorrow == token0 ? amount : 0;
        uint256 amountOut1 = tokenBorrow == token1 ? amount : 0;
        _owner = msg.sender;
        console.log("amountOut0:", amountOut0, " amountOut1:",amountOut1);
        IUniswapV2Pair(pair1).swap(
            amountOut0, 
            amountOut1, 
            address(this), 
            data
        );
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        (address tokenBorrow, uint256 amountBorrow) = abi.decode(data, (address, uint256));
        address pair1 = IUniswapV2Factory(_factoryA).getPair(_tokenA, _tokenB);
        if (msg.sender != pair1) {
            revert('FlashSwap: Unauthorized');
        }

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address tokenRepay = tokenBorrow == token0 ? token1 : token0;

        //外层借用x,则调用的是swap(0, x), 所以外层的path是[0到x]
        address[] memory pathLend = new address[](2);
        pathLend[0] = tokenRepay;// 0
        pathLend[1] = tokenBorrow;// x

        uint256[] memory lendingAmountsIn = IUniswapV2Router02(_uniswapRouterA).getAmountsIn(amountBorrow, pathLend);
        uint256 amountToRepay = lendingAmountsIn[0];// 手续费包含在getAmountsIn中
        
        IERC20(tokenBorrow).approve(_uniswapRouterB, amountBorrow);
        //用借来的token进行交易换取另一个token
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = tokenBorrow;// x
        pathSwap[1] = tokenRepay;// y
        IUniswapV2Router02(_uniswapRouterB).swapExactTokensForTokens(
            amountBorrow,
            amountToRepay,
            pathSwap,
            address(this),
            block.timestamp + 1000
        );

        //还款
        IERC20(tokenRepay).transfer(msg.sender, amountToRepay); 
        //利润打给owner
        IERC20(tokenRepay).transfer(_owner, IERC20(tokenRepay).balanceOf(address(this)));     
    }


}