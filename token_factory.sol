pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUSDT {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IBridge {
    function bridgeUSDT(address recipient, uint256 amount) external;
}

contract TokenFactory is Ownable {
    uint256 public constant CREATION_FEE = 5 * 10**6; // 5 USDT (6 decimals)
    address public constant USDT_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDT on Base (replace with actual address)
    address public constant ETHEREUM_FEE_RECIPIENT = 0xd57407f87FaeDea87d32C88beA92298A7B1D58E8; // Ethereum address
    address public bridgeAddress; // Bridge contract address (set by owner)

    IUSDT public usdt;

    event TokenCreated(address indexed tokenAddress, string name, string symbol, uint256 totalSupply);
    event FeeBridged(address indexed user, uint256 amount, address recipient);

    constructor(address _bridgeAddress) Ownable(msg.sender) {
        usdt = IUSDT(USDT_ADDRESS);
        bridgeAddress = _bridgeAddress;
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) external {
        require(totalSupply > 0, "Total supply must be greater than 0");
        
        // Collect 5 USDT fee
        bool success = usdt.transferFrom(msg.sender, address(this), CREATION_FEE);
        require(success, "USDT transfer failed");

        // Create new token
        ERC20Token newToken = new ERC20Token(name, symbol, totalSupply, msg.sender);
        
        // Bridge USDT fee to Ethereum
        usdt.approve(bridgeAddress, CREATION_FEE);
        IBridge(bridgeAddress).bridgeUSDT(ETHEREUM_FEE_RECIPIENT, CREATION_FEE);

        emit TokenCreated(address(newToken), name, symbol, totalSupply);
        emit FeeBridged(msg.sender, CREATION_FEE, ETHEREUM_FEE_RECIPIENT);
    }

    function setBridgeAddress(address _newBridgeAddress) external onlyOwner {
        bridgeAddress = _newBridgeAddress;
    }

    function withdrawStuckUSDT() external onlyOwner {
        uint256 balance = usdt.balanceOf(address(this));
        require(balance > 0, "No USDT to withdraw");
        usdt.transfer(owner(), balance);
    }
}

contract ERC20Token is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address initialOwner
    ) ERC20(name, symbol) {
        _mint(initialOwner, totalSupply * 10**decimals());
    }
}
