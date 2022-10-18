// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";

import "./P2P_SolarT.sol";
import "./P2P_MarketPlace.sol"; //using the whitelist contract


//Initializable already included in ERC20Upgradeable
contract P2P_FungibleSolar is BaseRelayRecipient, ERC20Upgradeable, ERC20BurnableUpgradeable {


    uint256 public collateral_ratio;
    uint256 public interrest_rate;

    address public USDC_contract_address;
    address public SolarT_contract_address; //SolarT address on Polygon
    address public P2PMarketplace_contract_address;
    address Aurelien_address;
    address Jonathan_address;
    address P2P_address;
    address owner;
    address contract_creator;

    mapping (address => uint256) public Staked_SolarTs;
    mapping (uint256 => address) public SolarT_Owner;
    mapping (uint256 => uint256) public SolarT_Values;
    mapping (uint256 => uint256) public SolarT_Remaining_payments;
    mapping (uint256 => uint256) public SolarT_blocked_income;
    mapping (uint256 => uint256) public Borrowed_amount;
    mapping (uint256 => uint256) public Timestamp_borrowed;
    string public override versionRecipient;

    /*
    Modifier that could be used for future updates
    modifier onlyAdmin {
        require(P2P_SolarT(SolarT_contract_address).hasRole(P2P_SolarT(SolarT_contract_address).ADMIN_ROLE(), _msgSender()), "Only Admin-P2P");
        _;
    }
    modifier onlyP2P {
        require(P2P_SolarT(SolarT_contract_address).hasRole(P2P_SolarT(SolarT_contract_address).P2P_ROLE(), _msgSender()), "Only P2P");
        _;
    }
    */

    function void () public {}

    function initialize (address _SolarT_contract_address, address _owner, address _USDC_contract_address, address forwarder_) public initializer
    {
        
        __ERC20_init("FS", "FS");
        _setTrustedForwarder(forwarder_);
        
        owner = _owner; //The owner can withdraw all the money
        contract_creator = _msgSender();
        SolarT_contract_address = _SolarT_contract_address;
        collateral_ratio = 85;
        interrest_rate = 3;
        versionRecipient = "2.2.0";

        USDC_contract_address = _USDC_contract_address;
        //USDC_contract_address = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; //USDC address on Polygon
        //USDC_contract_address = 0xeE36A294369bE640Ce839F195f430A461ab6DA89; // USDC address on Polygon Testnet (Mumbai)
        Aurelien_address = 0xe7E3E925E5dcFeaF5C5CEBfbc6EfD4B404B0e607;
        Jonathan_address = 0xC117E7247be4830D169da13427311F59BD25d669;
        P2P_address = 0x3A8A9087379E03cE3789E34fCaf34eB19b7389c3;

    } 

    function update_addresses(address _P2PMarketplace_contract_address) public 
    {
         require(_msgSender() == owner || _msgSender() == contract_creator || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
         P2PMarketplace_contract_address = _P2PMarketplace_contract_address;

    } 

    function update_interrest_rate(uint256 _rate) public
    {
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        interrest_rate = _rate;
    }

    function update_collateral_ratio(uint256 _ratio) public
    {
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        collateral_ratio = _ratio;
    }

    function update_trusted_forwarder(address forwarder_) public
    {
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        _setTrustedForwarder(forwarder_);
    }

    function _msgSender() internal view override(ContextUpgradeable, BaseRelayRecipient)
        returns (address sender) {
        sender = BaseRelayRecipient._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, BaseRelayRecipient)
        returns (bytes calldata) {
        return BaseRelayRecipient._msgData();
    }

    function is_staked(uint256 Solar_tokenID) public view returns(bool)
    {
        return (SolarT_Owner[Solar_tokenID] != 0x0000000000000000000000000000000000000000);
    }

    function stake_SolarT(uint256 Solar_tokenID) public {

        //Verify if sender has the SolarT NFT
        require(P2P_SolarT(SolarT_contract_address).ownerOf(Solar_tokenID) == _msgSender(), "You dont own this SolarT");
        if (P2P_SolarT(SolarT_contract_address).is_using_whitelist()== true) {
            require(P2P_SolarT(SolarT_contract_address).is_in_whitelist(_msgSender()), 'Only whitelisted addresses can use the loan service');
        }


        // transfer the SolarT NFT from the sender to this contract
        P2P_SolarT(SolarT_contract_address).transferFrom(_msgSender(), address(this), Solar_tokenID); //transferFrom(from, to, tokenId)

        //Mint FS to the stake
        uint256 FSamount = SolarT_Values[Solar_tokenID]*collateral_ratio/100;
        _mint(_msgSender(), FSamount);

        SolarT_Owner[Solar_tokenID] = _msgSender();
        Borrowed_amount[Solar_tokenID] = FSamount;
        Timestamp_borrowed[Solar_tokenID] = block.timestamp;
        Staked_SolarTs[SolarT_Owner[Solar_tokenID]] += 1;
    }   

    function stake_SolarT_batch(uint256[] memory Solar_tokenIDs) public {
        uint i=0;
        uint l = Solar_tokenIDs.length;
        for (i = 0; i < l; i++) {
            stake_SolarT(Solar_tokenIDs[i]);
            }
    }

    function unstake_SolarT(uint256 Solar_tokenID) public {

        //Verify if sender is owner of SolarTs
        require(SolarT_Owner[Solar_tokenID] == _msgSender(), "You already withdrawn, or are not the owner of this SolarT token");

        //Verify if NFT is in the contract
        require(P2P_SolarT(SolarT_contract_address).ownerOf(Solar_tokenID) == address(this), "This SolarT token is not in the contract, i.e. was already withdrawn");

        //Transfer and Burn FStokens
        uint256 FS_balance = balanceOf(_msgSender());
        uint256 FSamount = get_FSamount_due(Solar_tokenID);
        require (FS_balance >= FSamount, "Not enough FS to unstake SolarT");
        _burn(_msgSender(),FSamount);

        //Transfert Solar NFT back to user
        P2P_SolarT(SolarT_contract_address).transferFrom(address(this), _msgSender(), Solar_tokenID); //transferFrom(from, to, tokenId)

        //Transfert income from the panel to user
        

        uint256 amount_to_send = SolarT_blocked_income[Solar_tokenID];
        uint256 contract_balance = ERC20(USDC_contract_address).balanceOf(address(this));
        if ( contract_balance < amount_to_send)
        {   
            //withdraw SolarT income in case there isnt enough USD
            if (int(P2P_SolarT(SolarT_contract_address).Entilted_amount(address(this))) >= int(amount_to_send) - int(contract_balance)) //the right part should never be negative
            {
                P2P_SolarT(SolarT_contract_address).withdraw_profit();
            }
            else 
            {
                require(false, "There is not enough USD in the staking and SolarT contract, please contact P2P staff"); //should never happen
            }
        }

        if (amount_to_send > 0) 
        {
            ERC20(USDC_contract_address).transfer(_msgSender(), uint256(amount_to_send));
        }
        
        
        //reset parameters
        Staked_SolarTs[SolarT_Owner[Solar_tokenID]] -= 1;
        delete SolarT_Owner[Solar_tokenID];
        delete Borrowed_amount[Solar_tokenID];
        delete Timestamp_borrowed[Solar_tokenID];
        SolarT_blocked_income[Solar_tokenID] = 0;
    }

    function unstake_SolarT_batch(uint256[] memory Solar_tokenIDs) public {
        uint i=0;
        uint l = Solar_tokenIDs.length;
        for (i = 0; i < l; i++) {
            unstake_SolarT(Solar_tokenIDs[i]);
            }
    }


    function update_SolarT_value(uint256 Solar_tokenID, uint256 USD_value) public { //Should be updated every month by P2P after payment (Panel valuation for loan)
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address || _msgSender() == P2P_address || _msgSender() == SolarT_contract_address, "Only P2P");
        
        bool allowed = true; //panel value should never ecxeed 1k, protect us against amlicious attack
        {
            allowed = (USD_value < 1000*1e6); //USDC has 6 decimals
        }
        require(allowed, "USD_value above limit");
        SolarT_Values[Solar_tokenID] = USD_value;
    }

    function update_SolarT_remaining_payments(uint256 Solar_tokenID, uint256 remaining_payments) public {
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address || _msgSender() == P2P_address || _msgSender() == SolarT_contract_address, "Only P2P");
        SolarT_Remaining_payments[Solar_tokenID] = remaining_payments;
    }

    function update_SolarT_remaining_payments_batch(uint256[] memory Solar_tokenIDs, uint256[] memory remaining_payments) public {
        uint i=0;
        uint l = Solar_tokenIDs.length;
        for (i = 0; i < l; i++) {
            SolarT_Remaining_payments[Solar_tokenIDs[i]] = remaining_payments[i];
            }
    }

    
    function update_SolarT_value_batch(uint256[] memory Solar_tokenIDs, uint256[] memory USD_values) public { //Should be updated every month by P2P after payment (Panel valuation for loan)
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address || _msgSender() == P2P_address, "Only P2P");
        uint i=0;
        uint l = Solar_tokenIDs.length;
        for (i = 0; i < l; i++) {
            update_SolarT_value(Solar_tokenIDs[i], USD_values[i]);
            }
    }

    function add_SolarT_blocked_income(uint256 Solar_tokenID, uint256 USD_amount) public { //Should be updated every month by P2P after payment (income adds to the previous one)
    //Note that this is made automatically by the SolarT contract when calling "Add_SolarT_entilted_amount"
        require(_msgSender() == owner || _msgSender() == SolarT_contract_address || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        
        SolarT_blocked_income[Solar_tokenID] += USD_amount;
    }

    function update_SolarT_blocked_income(uint256 Solar_tokenID, uint256 USD_amount) public { //Should only be used in case of problem
        require(_msgSender() == owner || _msgSender() == SolarT_contract_address || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        SolarT_blocked_income[Solar_tokenID] = USD_amount;
    }





    //View only functions

    function get_collateral_value(uint256 Solar_tokenID) public view returns (uint256) {
        uint256 value = SolarT_Values[Solar_tokenID] + SolarT_blocked_income[Solar_tokenID];
        return value;
    }


    function get_FSamount_due(uint256 Solar_tokenID) public view returns (uint256) {
        uint256 amount_due;
        if (is_staked(Solar_tokenID)) {
            uint256 loan_duration = block.timestamp - Timestamp_borrowed[Solar_tokenID];
            //uint256 amount_due = Borrowed_amount[Solar_tokenID]*(1 + loan_duration*interrest_rate/100/31971556); ////// Linear approximation
            ///uint256 amount_due = Borrowed_amount[Solar_tokenID]*exp(interrest_rate/100 * loan_duration/31971556);  /////// interrest rate is in %/year, assuming 1y =  365d + 5h + 59min + 16s
            
            //https://www.npmjs.com/package/solidity-math-utils?activeTab=readme#analyticmath
            //uint256 amount_due = Borrowed_amount[Solar_tokenID]*pow(27182182845904523536, 10000000000000000000, interrest_rate/100 * loan_duration, 31971556);

            //https://ethereum.stackexchange.com/questions/35819/how-do-you-calculate-compound-interest-in-solidity
            
            /*
            uint q = 31971556*100/interrest_rate;
            if (loan_duration > 0) {
                amount_due = fracExp(Borrowed_amount[Solar_tokenID], q, loan_duration , loan_duration );
            }
            */
            if (loan_duration > 0) {
                amount_due = Borrowed_amount[Solar_tokenID]*(1 + loan_duration*interrest_rate/100/31971556); ////// Linear approximation
            }
            else {
                amount_due = Borrowed_amount[Solar_tokenID];
            }
        }

        
        return amount_due;
    }



    function fracExp(uint k, uint q, uint n, uint p) public pure returns (uint) {
        // Computes `k * (1+1/q) ^ N`, with precision `p`. The higher
        // the precision, the higher the gas cost. It should be
        // something around the log of `n`. When `p == n`, the
        // precision is absolute (sans possible integer overflows). <edit: NOT true, see comments>
        // Much smaller values are sufficient to get a great approximation.
        uint s = 0;
        uint N = 1;
        uint B = 1;
        for (uint i = 0; i < p; ++i){
            s += k * N / B / (q**i);
            N  = N * (n-i);
            B  = B * (i+1);
        }
        return s;
    }


    //List of all solarT holders for each token IDs and the amount of FS they borrowed
    function get_list_of_solarT_staker() public view returns(address[] memory, uint256[] memory) {

        uint l = P2P_SolarT(SolarT_contract_address).get_SolarT_amount();
        address[] memory address_list = new address[](l);
        uint256[] memory FS_borrow_amount_list = new uint256[](l);
        uint TokenID=0;
        for (TokenID = 0; TokenID < l; TokenID++) {
            address address_ = SolarT_Owner[TokenID];
            address_list[TokenID] = address_;
            FS_borrow_amount_list[TokenID] = get_FSamount_due(TokenID);
        }

        return (address_list, FS_borrow_amount_list); //returns the list of wallets currently staking SolarT and the amount of FS they owe
    }


    //List of all solarT tokens an owner has and their borrowed FS for each
    function get_list_of_solarT_staked(address _address) public view returns (uint256[] memory, uint256[] memory) {

        uint256[] memory SolarT_IDs = P2P_SolarT(SolarT_contract_address).SolarT_IDs_of(_address);
        uint i;
        uint l = SolarT_IDs.length;
        uint256[] memory FS_borrow_amount_list = new uint256[](l);
        for (i = 0; i < l; i++) {
            uint256 TokenID = SolarT_IDs[i];
            FS_borrow_amount_list[i] = get_FSamount_due(TokenID);
            }

        return (SolarT_IDs, FS_borrow_amount_list);
    }



    //Functions for Price Stability Mechanism (PSM)
    function exchange_FS_TO_USDC(uint256 amount) public {

        require(balanceOf(_msgSender()) >= amount, "You don't own enough FS to exchange");
        uint256 USDC_available_funds = ERC20(USDC_contract_address).balanceOf(address(this));
        uint256 USDC_available_funds_MarketPlace = P2P_MarketPlace(P2PMarketplace_contract_address).available_funds();
        uint256 total_available_funds = USDC_available_funds + USDC_available_funds_MarketPlace;
        require( total_available_funds >= amount, "Not enough USDC funds");

        if (USDC_available_funds < amount) {
            uint256 amount_to_transfert = amount - USDC_available_funds;
            P2P_MarketPlace(P2PMarketplace_contract_address).transfert_funds_to_FS_contract(amount_to_transfert);
        }

        _burn(_msgSender(),amount);
        ERC20(USDC_contract_address).transfer(_msgSender(), amount);
    }


    function exchange_USDC_TO_FS(uint256 amount) public {
        require(ERC20(USDC_contract_address).balanceOf(_msgSender()) >= amount, "You don't own enough USDC to exchange");
        ERC20(USDC_contract_address).transferFrom(_msgSender(), address(this), amount);
        _mint(_msgSender(), amount);
    }


    function Amount_in_contract() public view returns (uint256, uint256){
        uint256 USDC_available_funds = ERC20(USDC_contract_address).balanceOf(address(this));
        uint256 USDC_available_funds_MarketPlace = P2P_MarketPlace(P2PMarketplace_contract_address).available_funds();
        return (USDC_available_funds, USDC_available_funds_MarketPlace);
    }

}
