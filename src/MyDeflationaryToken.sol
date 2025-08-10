//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @title MyDeflationaryToken
 * @author ICON
 * @notice This contract implements a basic ERC20 token with a transfer fee mechanism.
 * It allows for minting, transferring, and burning tokens, with fees distributed to a treasury wallet,
 * a hodlers distribution wallet, and a burn mechanism.
 * The transfer fee is defined in basis points (1/100th of a percent) and can be set during contract deployment.
 * The contract also includes custom error messages for better clarity and gas efficiency.
 * This contract is designed to be simple and efficient, focusing on the core functionalities of an ERC20 token.
 */
contract MyDeflationaryToken {
    // Custom errors
    error MyDeflationaryToken__CantExceedMaxTransferFee();
    error MyDeflationaryToken__AllFeesMustSumUpToTransferFee();
    error MyDeflationaryToken__CantExceedTransferFee();
    error MyDeflationaryToken__CantBeZeroAddress();
    error MyDeflationaryToken__NotOwner();
    error MyDeflationaryToken__LesserBalance();
    error MyDeflationaryToken__NotApprovedForThisAmount();
    error MyDeflationaryToken__TransferFailed();

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // State variables
    uint256 public transferFee;
    uint256 public burnPercent;
    uint256 public hodlersPercent;
    uint256 public treasuryPercent;
    address public immutable treasuryWallet;
    address public immutable hodlersDistributionWallet;

    uint256 private constant MAX_TRANSFER_FEE = 10;
    uint256 private constant PRECISION = 100;
    address public immutable owner;
    string public constant name = "IconToken";
    string public constant symbol = "ICON";
    uint8 public constant decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) public balances;
    mapping(address owner => mapping(address spender => uint256 amount)) public approvals;

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert MyDeflationaryToken__NotOwner();
        }
        _;
    }

    // Constructor
    /**
     * @notice Initializes the token with the specified parameters.
     * @param _treasuryWallet The address of the treasury wallet.
     * @param _hodlersDistributionWallet The address for hodlers distribution.
     * @param _transferFee The fee charged on transfers, in basis points (1/100th of a percent).
     * @param _burnPercent The percentage of the transfer fee that is burned.
     * @param _treasuryPercent The percentage of the transfer fee that goes to the treasury.
     * @param _hodlersPercent The percentage of the transfer fee that is distributed to hodlers.
     */
    constructor(
        address _treasuryWallet,
        address _hodlersDistributionWallet,
        uint256 _transferFee,
        uint256 _burnPercent,
        uint256 _treasuryPercent,
        uint256 _hodlersPercent
    ) {
        owner = msg.sender;
        treasuryWallet = _treasuryWallet;
        if (_transferFee > MAX_TRANSFER_FEE) {
            revert MyDeflationaryToken__CantExceedMaxTransferFee();
        }
        transferFee = _transferFee;
        burnPercent = _burnPercent;
        treasuryPercent = _treasuryPercent;
        hodlersPercent = _hodlersPercent;
        uint256 allFees = burnPercent + treasuryPercent + hodlersPercent;
        if (allFees != _transferFee) {
            revert MyDeflationaryToken__AllFeesMustSumUpToTransferFee();
        }
        hodlersDistributionWallet = _hodlersDistributionWallet;
    }

    //////////////////////////
    // ERC20 Functions
    //////////////////////////

    function mint(address to, uint256 amount) public onlyOwner {
        if (to == address(0)) {
            revert MyDeflationaryToken__CantBeZeroAddress();
        }
        balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address receiver, uint256 amount) public returns (bool) {
        if (balances[msg.sender] < amount) {
            revert MyDeflationaryToken__LesserBalance();
        }
        if (receiver == address(0)) {
            revert MyDeflationaryToken__CantBeZeroAddress();
        }
        uint256 fee = (amount * transferFee) / PRECISION;
        uint256 burnShare = (burnPercent * amount) / PRECISION;
        uint256 hodlersShare = (hodlersPercent * amount) / PRECISION;
        uint256 treasury = (treasuryPercent * amount) / PRECISION;

        uint256 netAmount = amount - fee;
        balances[receiver] += netAmount;
        balances[treasuryWallet] += treasury;
        balances[hodlersDistributionWallet] += hodlersShare;
        balances[msg.sender] -= amount;
        _totalSupply -= burnShare; // Reduce total supply by the burned amount
        emit Transfer(msg.sender, receiver, netAmount);
        emit Transfer(msg.sender, treasuryWallet, treasury);
        emit Transfer(msg.sender, hodlersDistributionWallet, hodlersShare);
        emit Transfer(msg.sender, address(0), burnShare);
        return true;
    }

    function transferFrom(address sender, address receiver, uint256 amount) public returns (bool) {
        if (approvals[sender][msg.sender] < amount) {
            revert MyDeflationaryToken__NotApprovedForThisAmount();
        }
        if (balances[sender] < amount) {
            revert MyDeflationaryToken__LesserBalance();
        }
        if (sender == address(0) || receiver == address(0)) {
            revert MyDeflationaryToken__CantBeZeroAddress();
        }

        uint256 fee = (amount * transferFee) / PRECISION;
        uint256 burnShare = (burnPercent * amount) / PRECISION;
        uint256 hodlersShare = (hodlersPercent * amount) / PRECISION;
        uint256 treasury = (treasuryPercent * amount) / PRECISION;

        uint256 netAmount = amount - fee;
        balances[receiver] += netAmount;
        balances[treasuryWallet] += treasury;
        balances[hodlersDistributionWallet] += hodlersShare;
        balances[address(0)] += burnShare; // Burn the tokens
        balances[sender] -= amount;
        approvals[sender][msg.sender] -= amount; // Decrease the allowance
        _totalSupply -= burnShare; // Reduce total supply by the burned amount
        emit Transfer(sender, receiver, netAmount);
        emit Transfer(sender, treasuryWallet, treasury);
        emit Transfer(sender, hodlersDistributionWallet, hodlersShare);
        emit Transfer(sender, address(0), burnShare);

        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        approvals[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // Getters

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address user) public view returns (uint256) {
        return balances[user];
    }

    function allowance(address _owner, address spender) public view returns (uint256) {
        return approvals[_owner][spender];
    }
}
