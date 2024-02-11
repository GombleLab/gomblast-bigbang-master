// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import "./interfaces/IDistributor.sol";

contract Distributor is IDistributor, Ownable2Step {
    using SafeERC20 for IERC20;

    uint256 private constant _PRECISION = 1e24;

    IERC20 public immutable override rewardToken;
    ISwapRouter public immutable override swapRouter;

    uint256 public override rewardSnapshot = _PRECISION;
    uint256 public override totalReceivers;
    mapping(address => uint256) public override getUserSnapshot;

    constructor(address owner_, IERC20 rewardToken_, ISwapRouter swapRouter_) Ownable(owner_) {
        rewardToken = rewardToken_;
        swapRouter = swapRouter_;
    }

    function isRegistered(address user) public view returns (bool) {
        return getUserSnapshot[user] > 0;
    }

    function claimable(address user) public view returns (uint256) {
        unchecked {
            return isRegistered(user) ? (rewardSnapshot - getUserSnapshot[user]) / _PRECISION : 0;
        }
    }

    function distributeWithPermit(
        address payment,
        uint256 amount,
        uint256 minOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(payment).permit(msg.sender, address(this), amount, deadline, v, r, s);
        distribute(payment, amount, minOut);
    }

    function distribute(address payment, uint256 amount, uint256 minOut) public {
        IERC20(payment).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(payment).approve(address(swapRouter), amount);
        uint256 out = swapRouter.swap(payment, address(rewardToken), amount, minOut);
        rewardSnapshot += out * _PRECISION / totalReceivers;
        emit Distribute(payment, amount, out);
    }

    function claim(address user) public {
        uint256 amount = claimable(user);
        if (amount > 0) {
            getUserSnapshot[user] = rewardSnapshot;
            rewardToken.safeTransfer(user, amount);
            emit Claim(user, amount);
        }
    }

    function register(address receiver) external onlyOwner {
        if (isRegistered(receiver)) revert AlreadyRegistered();

        getUserSnapshot[receiver] = rewardSnapshot;
        unchecked {
            totalReceivers += 1;
        }
        emit Register(receiver);
    }

    function unregister(address receiver) external onlyOwner {
        if (!isRegistered(receiver)) revert NotRegistered();
        claim(receiver);

        getUserSnapshot[receiver] = 0;
        unchecked {
            totalReceivers -= 1;
        }
        emit Unregister(receiver);
    }
}
