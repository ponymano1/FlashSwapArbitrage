// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "../src/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "../src/FlashSwapArbitrage.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";


//weth:0x90527465701383F60ad4cfA4617B70B84e30857c

//factory:0x77073baF5b076f032Edc5e7000E82Fce8C8e24A3

//router:0x475221BE467a62eb2f0c654B08B696F3a5546f5f


//第二个uniswap v2
//factory:0x41E1FCB06Ed97B345F3B73ECF6ECb1C20a09FA0e

//router:0xAb379DE430F22040c1ce917BE63F01bDa68fbbb3


contract tokenT is ERC20Permit {
    // Your contract code here
    constructor(string memory name_, string memory symbol_, uint256 amount) ERC20(name_, symbol_) ERC20Permit(name_) {
        _mint(msg.sender, amount);
    }
    
}

contract FlashSwapArbitrageTest is Test {
    IUniswapV2Factory public factoryA;
    IUniswapV2Factory public factoryB;
    IUniswapV2Router02 public uniswapRouterA;
    IUniswapV2Router02 public uniswapRouterB;
    IERC20 public tokenA;
    IERC20 public tokenB;
    FlashSwapArbitrage public flashSwapArbitrage;

    address admin;
    address liqRecevier;
    address arbitrager;
    

    function setUp() public {
        factoryA = IUniswapV2Factory(address(0x77073baF5b076f032Edc5e7000E82Fce8C8e24A3));
        factoryB = IUniswapV2Factory(address(0x41E1FCB06Ed97B345F3B73ECF6ECb1C20a09FA0e));
        uniswapRouterA = IUniswapV2Router02(address(0x475221BE467a62eb2f0c654B08B696F3a5546f5f));
        uniswapRouterB = IUniswapV2Router02(address(0xAb379DE430F22040c1ce917BE63F01bDa68fbbb3));
        admin = makeAddr("myAdmin");
        liqRecevier = makeAddr("liqRecevier");
        arbitrager = makeAddr("arbitrager");
        vm.deal(admin, 100 ether);
        vm.startPrank(admin);
        {
            tokenA = new tokenT("tokenA", "TA", 100000 ether);
            tokenB = new tokenT("tokenB", "TB", 100000 ether);
            flashSwapArbitrage = new FlashSwapArbitrage(address(factoryA), address(factoryB), address(tokenA), address(tokenB), address(uniswapRouterA), address(uniswapRouterB), admin);
            

        }
        vm.stopPrank();
        addLiquidity(10000 ether, 10000 ether, uniswapRouterA);
        addLiquidity(10000 ether, 20000 ether, uniswapRouterB);

        
        
    }

    function test_startArbitrage() public {
        vm.startPrank(arbitrager);
        {
            uint256 balanceBBefore = tokenB.balanceOf(arbitrager);
            flashSwapArbitrage.startArbitrage(address(tokenA), 3000 ether);
            uint256 balanceBAfter = tokenB.balanceOf(arbitrager);
            console.log("balance before:", balanceBBefore, " balance after:", balanceBAfter);
            if(balanceBAfter <= balanceBBefore){
                console.log("arbitrage success");
                revert("arbitrage failed");
            }
        }
        vm.stopPrank();
    }


    function addLiquidity(uint256 amountA, uint256 amountB, IUniswapV2Router02 router) internal {
        vm.startPrank(admin);
        {
            tokenA.approve(address(router), amountA);
            tokenB.approve(address(router), amountB);
            router.addLiquidity(address(tokenA), address(tokenB), amountA , amountB , 1, 1, liqRecevier, block.timestamp + 10000);
            
        }
        vm.stopPrank();
    }
    
}

