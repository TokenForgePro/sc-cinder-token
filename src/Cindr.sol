// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {ICindr} from "src/interfaces/ICindr.sol";

/**
 * @title Cindr Token
 * @dev Implementation of the Cindr Token with reflection mechanism, auto liquidity, and fees for marketing and development.
 * Inspired by SafeMoon mechanisms and code: https://github.com/safemoonprotocol/Safemoon.sol/blob/main/Safemoon.sol
 */
contract Cindr is ICindr, Ownable {
    /************************************* Token description ****************************************/
    /// @notice Token name
    string private _name;

    /// @notice Token symbol
    string private _symbol;

    /// @notice Token decimals
    uint16 private _decimals = 9;
    /************************************************************************************************/

    /********************************** ERC20 Token mappings ****************************************/
    /// @notice Reflects the owned tokens of each address
    mapping(address => uint256) private _rOwned;

    /// @notice Actual token balance of each address
    mapping(address => uint256) private _tOwned;

    /// @notice Allowances for each address to spend on behalf of another address
    mapping(address => mapping(address => uint256)) private _allowances;
    /************************************************************************************************/

    /// @notice Tracks addresses that are excluded from fee
    mapping(address => bool) private _isExcludedFromFee;

    /// @notice Tracks addresses that are excluded from reward
    mapping(address => bool) private _isExcluded;

    /// @notice List of excluded addresses
    address[] private _excluded;

    /// @notice Maximum value for uint256
    uint256 private constant MAX = type(uint256).max;

    /// @notice Total supply of tokens
    uint256 private _tTotal;

    /// @notice Reflected total supply
    uint256 private _rTotal;

    /********************************* Fee Percentages and amounts ************************************/
    /// @notice Total fee collected
    uint256 private _tFeeTotal;

    /// @notice Current tax fee percentage
    uint16 public taxFee;

    /// @notice Previous tax fee percentage
    uint16 private _previousTaxFee = taxFee;

    /// @notice Current burn fee percentage
    uint16 public burnFee;

    /// @notice Previous burn fee percentage
    uint16 private _previousBurnFee = burnFee;

    /// @notice Current liquidity fee percentage
    uint16 public liquidityFee;

    /// @notice Previous liquidity fee percentage
    uint16 private _previousLiquidityFee = liquidityFee;

    /// @notice Current marketing fee percentage
    uint16 public marketingFee;

    /// @notice Previous marketing fee percentage
    uint16 private _previousMarketingFee = marketingFee;

    /************************************************************************************************/

    /********************************* Treasury Wallets ************************************/
    /// @notice Address of the marketing wallet
    address public marketingWallet;

    /************************************************************************************************/

    /********************************* Defi Behavior ************************************/
    /// @notice Instance of UniswapV2Router
    IUniswapV2Router02 public immutable uniswapV2Router;

    /// @notice Address of the UniswapV2 pair for this token
    address public immutable uniswapV2Pair;

    /// @notice Boolean to lock the swap and liquify process
    bool inSwapAndLiquify;

    /// @notice Flag to enable or disable swap and liquify
    bool public swapAndLiquifyEnabled = true;

    /// @notice Maximum transaction amount
    uint256 public _maxTxAmount = 5_000_000 * 10 ** 6 * 10 ** 9;

    /// @notice Number of tokens to sell and add to liquidity
    uint256 private numTokensSellToAddToLiquidity = 5_000_000 * 10 ** 9;
    /************************************************************************************************/

    /**
     * @dev Prevents reentrancy during the swap and liquify process
     * Sets the inSwapAndLiquify flag to true before executing the function and resets it to false after the function execution
     */
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    /**
     * @notice Constructor for the Cindr token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param totalSupply_ Total Supply of the token
     * @param _uniswapV2RouterAddress Address of the UniswapV2Router
     * @param _marketingWallet Address of the marketing wallet
     * @param _taxFee Tax fee percentage
     * @param _burnFee Burn fee percentage
     * @param _liquidityFee Liquidity fee percentage
     * @param _marketingFee Marketing fee percentage
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address _uniswapV2RouterAddress,
        address _marketingWallet,
        uint16 _taxFee,
        uint16 _burnFee,
        uint16 _liquidityFee,
        uint16 _marketingFee
    ) Ownable(_msgSender()) {
        // Ensure the parameters are valid
        require(bytes(name_).length > 0, "Token name cannot be empty");
        require(bytes(symbol_).length > 0, "Token symbol cannot be empty");

        require(totalSupply_ > 0, "Total supply must be greater than zero");
        require(
            _uniswapV2RouterAddress != address(0),
            "UniswapV2Router address cannot be zero address"
        );
        require(
            _marketingWallet != address(0),
            "Marketing wallet address cannot be zero address"
        );

        require(_taxFee <= 1000, "Tax fee must be between 0 and 100");
        require(_burnFee <= 1000, "Burn fee must be between 0 and 100");
        require(
            _liquidityFee <= 1000,
            "Liquidity fee must be between 0 and 100"
        );
        require(
            _marketingFee <= 1000,
            "Marketing fee must be between 0 and 100"
        );

        _tTotal = totalSupply_ * 10 ** 6 * 10 ** _decimals;
        _rTotal = (MAX - (MAX % _tTotal));
        _rOwned[_msgSender()] = _rTotal;

        _name = name_;
        _symbol = symbol_;

        taxFee = _taxFee;
        burnFee = _burnFee;
        liquidityFee = _liquidityFee;
        marketingFee = _marketingFee;

        marketingWallet = _marketingWallet;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _uniswapV2RouterAddress
        );

        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // Set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        // Exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[uniswapV2Pair] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    receive() external payable {}

    /************************************************************************************************/
    /****************************** EXTERNAL FUNCTIONS (ICindr INTERFACE) ****************************/
    /************************************************************************************************/
    /**
     * @dev See {ICindr-isExcludedFromReward}.
     */
    function isExcludedFromReward(
        address account
    ) external view returns (bool) {
        return _isExcluded[account];
    }

    /**
     * @dev See {ICindr-totalFees}.
     */
    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    /**
     * @dev See {ICindr-deliver}.
     */
    function deliver(uint256 tAmount) external {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );

        (uint256 rAmount, , , , , ) = _getValues(tAmount);

        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _rTotal = _rTotal - (rAmount);
        _tFeeTotal = _tFeeTotal + (tAmount);
    }

    /**
     * @dev See {ICindr-reflectionFromToken}.
     */
    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) external view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
     * @dev See {ICindr-excludeFromReward}.
     */
    function excludeFromReward(address account) external onlyOwner {
        require(
            account != address(uniswapV2Router),
            "We can not exclude Uniswap router."
        );

        require(!_isExcluded[account], "Account is already excluded");

        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }

        _isExcluded[account] = true;
        _excluded.push(account);
    }

    /**
     * @dev See {ICindr-includeInReward}.
     */
    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    /**
     * @dev See {ICindr-excludeFromFee}.
     */
    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    /**
     * @dev See {ICindr-includeInFee}.
     */
    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    /**
     * @dev See {ICindr-setTaxFeePercent}.
     */
    function setTaxFeePercent(uint16 _taxFee) external onlyOwner {
        _previousTaxFee = taxFee;

        taxFee = _taxFee;
    }

    /**
     * @dev See {ICindr-setBurnFeePercent}.
     */
    function setBurnFeePercent(uint16 _burnFee) external onlyOwner {
        _previousBurnFee = burnFee;

        burnFee = _burnFee;
    }

    /**
     * @dev See {ICindr-setLiquidityFeePercent}.
     */
    function setLiquidityFeePercent(uint16 _liquidityFee) external onlyOwner {
        _previousLiquidityFee = liquidityFee;

        liquidityFee = _liquidityFee;
    }

    /**
     * @dev See {ICindr-setMarketingFeePercent}.
     */
    function setMarketingFeePercent(uint16 _marketingFee) external onlyOwner {
        _previousLiquidityFee = marketingFee;

        marketingFee = _marketingFee;
    }

    /**
     * @dev See {ICindr-setMaxTxPercent}.
     */
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        _maxTxAmount = (_tTotal * (maxTxPercent)) / (10 ** 2);
    }

    /**
     * @dev See {ICindr-setSwapAndLiquifyEnabled}.
     */
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;

        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /************************************************************************************************/

    /************************************************************************************************/
    /****************************** PUBLIC FUNCTIONS (ERC20 INTERFACE) ****************************/
    /************************************************************************************************/
    /**
     * @dev See {IERC20-name}.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC20-symbol}.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC20-decimals}.
     */
    function decimals() public view returns (uint16) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];

        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev See {IERC20-transfer}.
     */
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Approves the specified amount of tokens for the specified spender
     * @param spender The address of the spender
     * @param amount The amount of tokens to approve
     */
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );

        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );

        return true;
    }
    /************************************************************************************************/

    /************************************************************************************************/
    /****************************** PUBLIC FUNCTIONS (ICindr INTERFACE) ****************************/
    /************************************************************************************************/
    /**
     * @dev See {ICindr-isExcludedFromFee}.
     */
    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
     * @dev See {ICindr-tokenFromReflection}.
     */
    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );

        uint256 currentRate = _getRate();

        return rAmount / (currentRate);
    }

    /************************************************************************************************/

    /************************************************************************************************/
    /****************************** PRIVATE FUNCTIONS (REFLECTION METHODOLOGY) ****************************/
    /************************************************************************************************/

    /**
     * @dev Distributes the fee by reducing the total reflections and adding to the total fee collected.
     * @param rFee The reflection fee to be subtracted from the total reflections.
     * @param tFee The token fee to be added to the total fee collected.
     */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - (rFee);

        _tFeeTotal = _tFeeTotal + (tFee);
    }

    /**
     * @dev Takes the liquidity fee from the transaction amount
     * @param tLiquidity The amount of tokens to be taken as liquidity fee
     */
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();

        uint256 rLiquidity = tLiquidity * (currentRate);

        _rOwned[address(this)] = _rOwned[address(this)] + (rLiquidity);

        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + (tLiquidity);
    }

    /**
     * @dev Removes all fees by setting them to 0 and stores their previous values
     */
    function _removeAllFee() private {
        if (
            taxFee == 0 &&
            liquidityFee == 0 &&
            burnFee == 0 &&
            marketingFee == 0
        ) return;

        _previousTaxFee = taxFee;
        _previousLiquidityFee = liquidityFee;
        _previousBurnFee = burnFee;
        _previousMarketingFee = marketingFee;
    }

    function _restoreAllFee() private {
        taxFee = _previousTaxFee;
        liquidityFee = _previousLiquidityFee;
        burnFee = _previousBurnFee;
        marketingFee = _previousMarketingFee;
    }

    /**
     * @dev Transfers tokens between addresses with fee considerations
     * @param sender The address sending the tokens
     * @param recipient The address receiving the tokens
     * @param amount The amount of tokens to transfer
     * @param takeFee Whether to apply fees to the transfer
     */
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) _removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) _restoreAllFee();
    }

    /**
     * @dev Standard transfer function applying fees
     * @param sender The address sending the tokens
     * @param recipient The address receiving the tokens
     * @param tAmount The amount of tokens to transfer
     */
    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);

        if (_rOwned[sender] < rAmount) {
            revert InsufficientBalance(sender, _rOwned[sender], rAmount);
        }

        _rOwned[sender] -= rAmount;
        _rOwned[recipient] += rTransferAmount;

        _takeLiquidity(tLiquidity);

        _takeBurnFromTAmount(tAmount);
        _takeMarketingFromTAmount(tAmount);

        _reflectFee(rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfers tokens to an excluded address with fee considerations
     * @param sender The address sending the tokens
     * @param recipient The address receiving the tokens
     * @param tAmount The amount of tokens to transfer
     */
    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);

        if (_rOwned[sender] < rAmount) {
            revert InsufficientBalance(sender, _rOwned[sender], rAmount);
        }

        _rOwned[sender] -= rAmount;
        _tOwned[recipient] += tTransferAmount;

        _rOwned[recipient] += rTransferAmount;

        _takeLiquidity(tLiquidity);

        _takeBurnFromTAmount(tAmount);
        _takeMarketingFromTAmount(tAmount);

        _reflectFee(rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfers tokens from an excluded address with fee considerations
     * @param sender The address sending the tokens
     * @param recipient The address receiving the tokens
     * @param tAmount The amount of tokens to transfer
     */
    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);

        if (_tOwned[sender] < tAmount) {
            revert InsufficientBalance(sender, _tOwned[sender], tAmount);
        }

        if (_rOwned[sender] < rAmount) {
            revert InsufficientReflectionBalance(
                sender,
                _rOwned[sender],
                rAmount
            );
        }

        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;

        _rOwned[recipient] += rTransferAmount;

        _takeLiquidity(tLiquidity);

        _takeBurnFromTAmount(tAmount);
        _takeMarketingFromTAmount(tAmount);

        _reflectFee(rFee, tFee);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfers tokens between two excluded addresses with fee considerations
     * @param sender The address sending the tokens
     * @param recipient The address receiving the tokens
     * @param tAmount The amount of tokens to transfer
     */
    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);

        if (_tOwned[sender] < tAmount) {
            revert InsufficientBalance(sender, _tOwned[sender], tAmount);
        }

        if (_rOwned[sender] < rAmount) {
            revert InsufficientReflectionBalance(
                sender,
                _rOwned[sender],
                rAmount
            );
        }

        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;

        _tOwned[recipient] += tTransferAmount;
        _rOwned[recipient] += rTransferAmount;

        _takeLiquidity(tLiquidity);

        _takeBurnFromTAmount(tAmount);
        _takeMarketingFromTAmount(tAmount);

        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Takes the burn fee from the transaction amount
     * @param tAmount The amount of tokens to be burned
     */
    function _takeBurnFromTAmount(uint256 tAmount) private {
        uint256 currentRate = _getRate();

        uint256 tBurn = _calculateBurnFee(tAmount);
        uint256 rBurn = tBurn * (currentRate);

        _rTotal = _rTotal - (rBurn);
        _tTotal = _tTotal - (tBurn);
    }

    /**
     * @dev Takes the marketing fee from the transaction amount
     * @param tAmount The amount of tokens to be taken as marketing fee
     */
    function _takeMarketingFromTAmount(uint256 tAmount) private {
        uint256 currentRate = _getRate();

        uint256 tMarketing = _calculateMarketingFee(tAmount);
        uint256 rMarketing = tMarketing * (currentRate);

        _rOwned[marketingWallet] += rMarketing;

        if (_isExcluded[marketingWallet])
            _tOwned[marketingWallet] += tMarketing;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner())
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            _swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    /**
     * @dev Swaps tokens for ETH and adds liquidity to Uniswap
     * @param contractTokenBalance The amount of tokens to swap and liquify
     */
    function _swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / (2);
        uint256 otherHalf = contractTokenBalance - (half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        _swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - (initialBalance);

        // add liquidity to uniswap
        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    /**
     * @dev Swaps the specified amount of tokens for ETH
     * @param tokenAmount The amount of tokens to swap for ETH
     */
    function _swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Adds liquidity to Uniswap
     * @param tokenAmount The amount of tokens to add as liquidity
     * @param ethAmount The amount of ETH to add as liquidity
     */
    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    /**
     * @dev Gets the values required for the transfer
     * @param tAmount The amount of tokens to transfer
     * @return The calculated values for the transfer
     */
    function _getValues(
        uint256 tAmount
    )
        private
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getTValues(tAmount);

        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );

        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    /**
     * @dev Gets the transaction values
     * @param tAmount The amount of tokens to transfer
     * @return The calculated values for the transaction
     */
    function _getTValues(
        uint256 tAmount
    ) private view returns (uint256, uint256, uint256) {
        uint256 tFee = _calculateTaxFee(tAmount);
        uint256 tLiquidity = _calculateLiquidityFee(tAmount);
        uint256 tBurn = _calculateBurnFee(tAmount);
        uint256 tMarketing = _calculateMarketingFee(tAmount);

        uint256 tTransferAmount = tAmount -
            tFee -
            tLiquidity -
            tBurn -
            tMarketing;

        return (tTransferAmount, tFee, tLiquidity);
    }

    /**
     * @dev Gets the current rate of reflections
     * @return The current rate of reflections
     */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();

        return rSupply / (tSupply);
    }

    /**
     * @dev Gets the current supply of tokens
     * @return The current supply of tokens
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);

            rSupply = rSupply - (_rOwned[_excluded[i]]);
            tSupply = tSupply - (_tOwned[_excluded[i]]);
        }

        if (rSupply < _rTotal / (_tTotal)) return (_rTotal, _tTotal);

        return (rSupply, tSupply);
    }

    /**
     * @dev Calculates the tax fee
     * @param _amount The amount of tokens to calculate the fee for
     * @return The calculated tax fee
     */
    function _calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return (_amount * (taxFee)) / (10 ** 3);
    }

    /**
     * @dev Calculates the burn fee
     * @param _amount The amount of tokens to calculate the fee for
     * @return The calculated burn fee
     */
    function _calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return (_amount * (burnFee)) / (10 ** 3);
    }

    /**
     * @dev Calculates the liquidity fee
     * @param _amount The amount of tokens to calculate the fee for
     * @return The calculated liquidity fee
     */
    function _calculateLiquidityFee(
        uint256 _amount
    ) private view returns (uint256) {
        return (_amount * (liquidityFee)) / (10 ** 3);
    }

    /**
     * @dev Calculates the marketing fee
     * @param _amount The amount of tokens to calculate the fee for
     * @return The calculated marketing fee
     */
    function _calculateMarketingFee(
        uint256 _amount
    ) private view returns (uint256) {
        return (_amount * (marketingFee)) / (10 ** 3);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    ) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * (currentRate);
        uint256 rFee = tFee * (currentRate);
        uint256 rLiquidity = tLiquidity * (currentRate);

        uint256 rTransferAmount = rAmount - (rFee) - (rLiquidity);

        return (rAmount, rTransferAmount, rFee);
    }
}
