// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GMOVE is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public MOVE;

    uint256 public interestRate; // 500 = 5%
    uint256 public constant INTEREST_RATE_DENOMINATOR = 10000;
    uint256 public constant MAX_INTEREST_RATE = 1000; // 10%

    uint256 public initialExchangeRate;
    uint256 public lastUpdateTimestamp;
    uint256 public currentExchangeRate;

    event InterestRateUpdated(uint256 oldRate, uint256 newRate);
    event ExchangeRateUpdated(uint256 newRate);
    event Deposit(address indexed user, uint256 move, uint256 gmove);
    event Withdraw(address indexed user, uint256 gmove, uint256 move);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _move,
        address initialOwner
    ) public initializer {
        require(_move != address(0), "Invalid MOVE address");

        __ERC20_init("GMOVE", "GMOVE");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);

        MOVE = IERC20(_move);
        interestRate = 0;
        initialExchangeRate = 1e18;
        lastUpdateTimestamp = block.timestamp;
        currentExchangeRate = initialExchangeRate;
    }

    //////////////////////////////////// ADMIN ////////////////////////////////////

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setInterestRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= MAX_INTEREST_RATE, "Rate too high");

        updateExchangeRate();

        uint256 oldRate = interestRate;
        interestRate = _newRate;

        emit InterestRateUpdated(oldRate, _newRate);
    }

    function updateExchangeRate() public {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;

        if (timeElapsed == 0 || interestRate == 0) {
            return;
        }

        // Ignoring compound interest
        uint256 interestAccrued = (interestRate * timeElapsed * 1e18) /
            (365 days * INTEREST_RATE_DENOMINATOR);
        currentExchangeRate = currentExchangeRate + interestAccrued;
        lastUpdateTimestamp = block.timestamp;

        emit ExchangeRateUpdated(currentExchangeRate);
    }

    //////////////////////////////////// USER ////////////////////////////////////

    function deposit(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        updateExchangeRate();
        MOVE.safeTransferFrom(msg.sender, address(this), amount);
        uint256 gMOVE = (amount * 1e18) / currentExchangeRate;
        _mint(msg.sender, gMOVE);
        emit Deposit(msg.sender, amount, gMOVE);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient GMOVE balance");
        updateExchangeRate();
        uint256 move = (amount * currentExchangeRate) / 1e18;
        require(
            MOVE.balanceOf(address(this)) >= move,
            "Insufficient MOVE in contract"
        );
        _burn(msg.sender, amount);
        MOVE.safeTransfer(msg.sender, move);
        emit Withdraw(msg.sender, amount, move);
    }

    //////////////////////////////////// VIEW ////////////////////////////////////

    function exchangeRate() public view returns (uint256) {
        if (block.timestamp == lastUpdateTimestamp || interestRate == 0) {
            return currentExchangeRate;
        }
        // Ignoring compound interest
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        uint256 interestAccrued = (interestRate * timeElapsed * 1e18) /
            (365 days * INTEREST_RATE_DENOMINATOR);

        return currentExchangeRate + interestAccrued;
    }

    function getMOVE(uint256 gMOVE) external view returns (uint256) {
        return (gMOVE * exchangeRate()) / 1e18;
    }

    function getgMOVE(uint256 move) external view returns (uint256) {
        return (move * 1e18) / exchangeRate();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}
