// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CToken.sol";
import "./PriceOracle.sol";

contract UnitrollerAdminStorage {
    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Active brains of Unitroller
    */
    address public comptrollerImplementation;

    /**
    * @notice Pending brains of Unitroller
    */
    address public pendingComptrollerImplementation;
}

contract ComptrollerV1Storage is UnitrollerAdminStorage {

    /**
     * @notice Oracle which gives the price of any given asset
     */
    PriceOracle public oracle;

    /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
     //当用户的债务超过资产的抵押率的时候 ，最多清算（债务 - 资产）* 50%
     //清算：总的业务逻辑是帮别人还钱，然后拿到赎回的cToken。此刻清算者拿到的cToken数量比偿还等额的自己的债务得到的cToken数量多，多的一部分cToken即是清算者的激励
    uint public closeFactorMantissa;

    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives
     */
     //帮别人偿还债务时候 多获得的8%的cToken作为奖励  即：1.08
    uint public liquidationIncentiveMantissa;

    /**
     * @notice Max number of assets a single account can participate in (borrow or use as collateral)
     */
    //一个账户最多可参与的资产数量(借款或用作抵押) 
    // 20
    uint public maxAssets;

    /**
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
     //user => cToken[]   贷款和存款
    mapping(address => CToken[]) public accountAssets;

}

contract ComptrollerV2Storage is ComptrollerV1Storage {
    //某个资产的market  如：usdt的market
    struct Market {
        // Whether or not this market is listed
        //这个资产是否被列入市场
        bool isListed;

        //  Multiplier representing the most one can borrow against their collateral in this market.
        //  For instance, 0.9 to allow borrowing 90% of collateral value.
        //  Must be between 0 and 1, and stored as a mantissa.
        //抵押率，超额抵押，借出百分之90你的存款金额，若为0 则只能存款流动性挖矿，不能作为抵押物进行借贷 
        uint collateralFactorMantissa;

        // Per-market mapping of "accounts in this asset"
        //账户是否进入这个market    该资产是否可以抵押
        mapping(address => bool) accountMembership;

        // Whether or not this market receives COMP
        //废弃
        bool isComped;
    }

    /**
     * @notice Official mapping of cTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;


    /**
     * @notice The Pause Guardian can pause certain actions as a safety mechanism.
     *  Actions which allow users to remove their own assets cannot be paused.
     *  Liquidation / seizing / transfer can only be paused globally, not by market.
     */
     //治理：安全操作 暂停某些操作
     //pauseGuardian暂停权力的地址
    address public pauseGuardian;
    //暂停存款---总开关
    bool public _mintGuardianPaused;
    //暂停借款
    bool public _borrowGuardianPaused;
    //暂停转让
    bool public transferGuardianPaused;
    //暂停查封
    bool public seizeGuardianPaused;
    //每个cToken的暂停子开关
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;
}

contract ComptrollerV3Storage is ComptrollerV2Storage {
    struct CompMarketState {
        // The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        // The block number the index was last updated at
        uint32 block;
    }

    /// @notice A list of all markets
    //市场的所有cToken
    CToken[] public allMarkets;

    /// @notice The rate at which the flywheel distributes COMP, per block
    uint public compRate;

    /// @notice The portion of compRate that each market currently receives
    mapping(address => uint) public compSpeeds;

    /// @notice The COMP market supply state for each market
    mapping(address => CompMarketState) public compSupplyState;

    /// @notice The COMP market borrow state for each market
    mapping(address => CompMarketState) public compBorrowState;

    /// @notice The COMP borrow index for each market for each supplier as of the last time they accrued COMP
    mapping(address => mapping(address => uint)) public compSupplierIndex;

    /// @notice The COMP borrow index for each market for each borrower as of the last time they accrued COMP
    //各市场下 每个用户地址的指数
    mapping(address => mapping(address => uint)) public compBorrowerIndex;

    /// @notice The COMP accrued but not yet transferred to each user
    //每个用户未体现的COMP
    mapping(address => uint) public compAccrued;
}

contract ComptrollerV4Storage is ComptrollerV3Storage {
    // @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap could disable borrowing on the given market.
    address public borrowCapGuardian;

    // @notice Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.
    //每个token的总借贷上限 不区分用户
    mapping(address => uint) public borrowCaps;
}

//V5、V6关于comp的治理
contract ComptrollerV5Storage is ComptrollerV4Storage {
    /// @notice The portion of COMP that each contributor receives per block
    //每个贡献者在每个块上收到的COMP的部分  
    mapping(address => uint) public compContributorSpeeds;

    /// @notice Last block at which a contributor's COMP rewards have been allocated
    mapping(address => uint) public lastContributorBlock;
}

contract ComptrollerV6Storage is ComptrollerV5Storage {
    /// @notice The rate at which comp is distributed to the corresponding borrow market (per block)
    mapping(address => uint) public compBorrowSpeeds;

    /// @notice The rate at which comp is distributed to the corresponding supply market (per block)
    mapping(address => uint) public compSupplySpeeds;
}

contract ComptrollerV7Storage is ComptrollerV6Storage {
    /// @notice Flag indicating whether the function to fix COMP accruals has been executed (RE: proposal 62 bug)
    bool public proposal65FixExecuted;

    /// @notice Accounting storage mapping account addresses to how much COMP they owe the protocol.
    mapping(address => uint) public compReceivable;
}
