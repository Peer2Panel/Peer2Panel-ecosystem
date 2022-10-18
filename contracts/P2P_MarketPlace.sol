// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";

import "./P2P_SolarT.sol";


contract P2P_MarketPlace is BaseRelayRecipient, Initializable {

    uint256 percentage_taken_from_transaction;
    address public SolarT_contract_address; //SolarT address on Polygon
    address public P2PFungibleSolar_contract_address; //P2PFungibleSolar_contract_address
    address public USDC_contract_address;
    address Aurelien_address;
    address Jonathan_address;
    address P2P_address;
    address owner;
    uint256 public Comission_USDC;
    string public override versionRecipient;
    
    mapping (address => uint256) public Listed_SolarTs;
    mapping (uint256 => uint256[]) public Price_history;  //
    mapping (uint256 => address) public SolarT_Owner;     //Keep track of the true NFT owner
    mapping (uint256 => uint256) public SolarT_Price;     //Listing price of the SolarT in USDC
    mapping (uint256 => uint256) public SolarT_Bid;
    mapping (uint256 => address) public Address_Bid;


    function void () public {}

    function initialize(address _SolarT_contract_address, address _P2PFungibleSolar_contract_address, address _owner, address _USDC_contract_address, address forwarder_) public initializer
    {
        
        _setTrustedForwarder(forwarder_);
        
        owner = _owner; //The owner can withdraw all the money from commission
        SolarT_contract_address = _SolarT_contract_address;
        P2PFungibleSolar_contract_address = _P2PFungibleSolar_contract_address;
        Comission_USDC = 0; //Keep track of the USDC received by the contract from commission
        percentage_taken_from_transaction = 1;
        versionRecipient = "2.2.0";

        USDC_contract_address = _USDC_contract_address;
        //USDC_contract_address = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // USDC address on Polygon
        //USDC_contract_address = 0xeE36A294369bE640Ce839F195f430A461ab6DA89; // USDC address on Polygon Testnet (Mumbai)
        Aurelien_address = 0xe7E3E925E5dcFeaF5C5CEBfbc6EfD4B404B0e607;
        Jonathan_address = 0xC117E7247be4830D169da13427311F59BD25d669;
        P2P_address = 0x3A8A9087379E03cE3789E34fCaf34eB19b7389c3;
    } 


    function update_trusted_forwarder(address forwarder_) public
    {
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        _setTrustedForwarder(forwarder_);
    }


    function change_commission(uint256 _percentage_taken_from_transaction) public {
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        percentage_taken_from_transaction = _percentage_taken_from_transaction;
    }

     function get_SolarT_owners_in_Marketplace() public view returns(address[] memory) {

        uint l = P2P_SolarT(SolarT_contract_address).get_SolarT_amount();
        address[] memory address_list = new address[](l);
        uint TokenID=0;
        for (TokenID = 0; TokenID < l; TokenID++) {
            address address_ = SolarT_Owner[TokenID];
            address_list[TokenID] = address_;
        }

        return address_list; //returns the list of wallets currently owning SolarT
    }   

    function is_listed (uint256 Solar_tokenID) public view returns(bool)
    {
        return (SolarT_Price[Solar_tokenID] != 0);
    }

    function last_sell_price(uint256 Solar_tokenID) public view returns(uint256)
    {
        uint lastIndex = Price_history[Solar_tokenID].length-1;
        return (Price_history[Solar_tokenID][lastIndex]);
    }


    function list_SolarT (uint256 Solar_tokenID, uint256 USDC_price) public  {

        //Verify if sender has the SolarT NFT
        require(P2P_SolarT(SolarT_contract_address).ownerOf(Solar_tokenID) == _msgSender(), "You dont own or already listed this SolarT");

        // transfer the SolarT NFT from the sender to this contract
        P2P_SolarT(SolarT_contract_address).transferFrom(_msgSender(), address(this), Solar_tokenID); //transferFrom(from, to, tokenId)

        //add listing informations
        SolarT_Owner[Solar_tokenID] = _msgSender();
        SolarT_Price[Solar_tokenID] = USDC_price;
        Listed_SolarTs[SolarT_Owner[Solar_tokenID]] += 1;
    }

    function list_SolarT_batch (uint256[] memory Solar_tokenIDs, uint256[] memory USDC_prices) public  {

        uint i=0;
        uint l = Solar_tokenIDs.length;
        for (i = 0; i < l; i++) {
            list_SolarT(Solar_tokenIDs[i], USDC_prices[i]);
            }
    }

    function update_listing_price_SolarT (uint256 Solar_tokenID, uint256 new_USDC_price) public  {

        //Verify if sender has the SolarT NFT
        require(SolarT_Owner[Solar_tokenID] == _msgSender(), "You dont own or already sold this SolarT");
        require(P2P_SolarT(SolarT_contract_address).ownerOf(Solar_tokenID) == address(this), "You did not list, already sold, or are not the owner of this SolarT token");
        require(new_USDC_price > SolarT_Bid[Solar_tokenID], "New price should be higher than current bid");

        //update listing informations
        SolarT_Price[Solar_tokenID] = new_USDC_price;
    }

    function unlist_SolarT (uint256 Solar_tokenID) public  {

        //Verify if sender is owner of SolarTs
        require(SolarT_Owner[Solar_tokenID] == _msgSender(), "You did not list, already sold, or are not the owner of this SolarT token");

        //Verify if NFT is in the contract
        require(P2P_SolarT(SolarT_contract_address).ownerOf(Solar_tokenID) == address(this), "This SolarT token is not in the contract, i.e. was already withdrawn or sold");

        // transfer the SolarT NFT from this contract to the owner
        P2P_SolarT(SolarT_contract_address).transferFrom(address(this),_msgSender(), Solar_tokenID);

        //remove listing informations
        Listed_SolarTs[SolarT_Owner[Solar_tokenID]] -= 1;
        delete SolarT_Price[Solar_tokenID];
        delete SolarT_Owner[Solar_tokenID];
        delete SolarT_Bid[Solar_tokenID];
        delete Address_Bid[Solar_tokenID];
    }

    function buy_SolarT (uint256 Solar_tokenID) public  {

        bool allowed_to_buy = (P2P_SolarT(SolarT_contract_address).get_owned_SolarTs(_msgSender()) < P2P_SolarT(SolarT_contract_address).max_solar_amount()) || P2P_SolarT(SolarT_contract_address).Allowed_addresses_unlimited(_msgSender()) == true;
        require(allowed_to_buy == true, 'you already own the maximum amount of SolarT');

        //Verify if NFT is in the contract
        require(P2P_SolarT(SolarT_contract_address).ownerOf(Solar_tokenID) == address(this), "This SolarT is not available for buy");
        uint256 users_found = ERC20(USDC_contract_address).balanceOf(_msgSender());
        require(users_found >= SolarT_Price[Solar_tokenID], "You dont have enough money to buy this pannel");

        ERC20(USDC_contract_address).transferFrom(_msgSender(), address(this), SolarT_Price[Solar_tokenID]);
        // Pay the previous owner USDC minus transaction fee, the contract keep the rest
        uint256 amount_to_send = (100-percentage_taken_from_transaction)*SolarT_Price[Solar_tokenID]/100;
        ERC20(USDC_contract_address).transfer(SolarT_Owner[Solar_tokenID], amount_to_send);
        Comission_USDC += percentage_taken_from_transaction*SolarT_Price[Solar_tokenID]/100;

        // Transfer the SolarT NFT from this contract to the new owner
        P2P_SolarT(SolarT_contract_address).transferFrom(address(this),_msgSender(), Solar_tokenID);
        
        // Remove the SolarT from the listing
        Listed_SolarTs[SolarT_Owner[Solar_tokenID]] -= 1;
        Price_history[Solar_tokenID].push(SolarT_Price[Solar_tokenID]);
        delete SolarT_Price[Solar_tokenID];
        delete SolarT_Owner[Solar_tokenID];
        delete SolarT_Bid[Solar_tokenID];
        delete Address_Bid[Solar_tokenID];
    }


    function place_bid (uint256 Solar_tokenID, uint256 USDC_amount) public  { //Can only place bid if higher than the existing bid

        bool allowed_to_buy = (P2P_SolarT(SolarT_contract_address).get_owned_SolarTs(_msgSender()) < P2P_SolarT(SolarT_contract_address).max_solar_amount()) || P2P_SolarT(SolarT_contract_address).Allowed_addresses_unlimited(_msgSender()) == true;
        require(allowed_to_buy == true, 'you already own the maximum amount of SolarT');

        require(USDC_amount > SolarT_Bid[Solar_tokenID], "New bid needs to be higher than current bid");
        require(USDC_amount < SolarT_Price[Solar_tokenID], "New bid needs to be lower than current price");

        address previous_bidder_address = Address_Bid[Solar_tokenID];
        uint256 previous_bid = SolarT_Bid[Solar_tokenID];

        //New bid
        ERC20(USDC_contract_address).transferFrom(_msgSender(), address(this), USDC_amount);

        //return money to previous bidder
        if (previous_bid > 0) {
            ERC20(USDC_contract_address).transfer(previous_bidder_address, previous_bid);
        }

        SolarT_Bid[Solar_tokenID] = USDC_amount;
        Address_Bid[Solar_tokenID] = _msgSender();

    }


    function withdraw_bid (uint256 Solar_tokenID) public  {

        require(_msgSender() == Address_Bid[Solar_tokenID], "You need to be the latest bidder to withdraw, or the asset was already sold");

        ERC20(USDC_contract_address).transfer(Address_Bid[Solar_tokenID], SolarT_Bid[Solar_tokenID]);
        delete SolarT_Bid[Solar_tokenID];
        delete Address_Bid[Solar_tokenID];

    }


    function accept_bid (uint256 Solar_tokenID) public  {

        require(_msgSender() == SolarT_Owner[Solar_tokenID], "You need to be the current SolarT owner");

        //Such conflict may happen if someone withdraw his bid shortly before the owner accept bid.
        require(SolarT_Bid[Solar_tokenID] > 0, "Dont accept a bid of 0 !");
        require(Address_Bid[Solar_tokenID] != address(0), "Dont send your NFT to null address");

        // Pay the previous owner USDC minus transaction fee, the contract keep the rest
        uint256 amount_to_send = (100-percentage_taken_from_transaction)*SolarT_Bid[Solar_tokenID]/100;
        ERC20(USDC_contract_address).transfer(SolarT_Owner[Solar_tokenID], amount_to_send);
        Comission_USDC += percentage_taken_from_transaction*SolarT_Bid[Solar_tokenID]/100;

        // Transfer the SolarT NFT from this contract to the new owner
        P2P_SolarT(SolarT_contract_address).transferFrom(address(this),_msgSender(), Solar_tokenID);

        // Remove the SolarT from the listing
        Listed_SolarTs[SolarT_Owner[Solar_tokenID]] -= 1;
        Price_history[Solar_tokenID].push(SolarT_Price[Solar_tokenID]);
        delete SolarT_Price[Solar_tokenID];
        delete SolarT_Owner[Solar_tokenID];
        delete SolarT_Bid[Solar_tokenID];
        delete Address_Bid[Solar_tokenID];

    }




    //Owner only functions


    function get_USDC_Balcance() public view returns(uint256) { //Current banlance of the contract
        uint256 current_balance = ERC20(USDC_contract_address).balanceOf(address(this));
        return current_balance;
    }


    function withdraw_commission_USDC() public { //P2P can withdraw the comission
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address || _msgSender() == P2P_address, "Only P2P");
        uint256 current_balance = ERC20(USDC_contract_address).balanceOf(address(this));
        require (current_balance < ERC20(USDC_contract_address).balanceOf(address(this)), "Current USDC founds are less than comission");
        ERC20(USDC_contract_address).transfer(owner, Comission_USDC);
    }


    function Update_commission_USDC(uint256 _CommissionUSDC) public { //SHould only be used in case of problems
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        Comission_USDC = _CommissionUSDC;
    }


    function withdraw_USDC_funds(uint256 amount) public { //Should only be used in case of problems
        require(_msgSender() == owner);
        uint256 current_balance = ERC20(USDC_contract_address).balanceOf(address(this));
        require (amount > 0, "Amount should be higher than 0");
        require (current_balance > amount, "Not enough USDC to withdraw");
        ERC20(USDC_contract_address).transfer(owner, amount);
    }


    function withdraw_all_USDC_funds() public { //Should only be used in case of problems
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        uint256 current_balance = ERC20(USDC_contract_address).balanceOf(address(this));
        require (current_balance > 0, "Current USDC founds are empty");
        ERC20(USDC_contract_address).transfer(owner, current_balance);
    }

   function withdraw_SolarT(uint256 Solar_tokenID) public { //Should only be used in case of problems
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        require(address(this) == P2P_SolarT(SolarT_contract_address).ownerOf(Solar_tokenID), "This token is not in the market place");
        P2P_SolarT(SolarT_contract_address).transferFrom(address(this), owner, Solar_tokenID);
    }

   function withdraw_all_SolarTs() public { //Should only be used in case of problems
        require(_msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address, "Only P2P");
        uint l = P2P_SolarT(SolarT_contract_address).get_SolarT_amount();
        uint TokenID=0;
        for (TokenID = 0; TokenID < l; TokenID++) {
            if (address(this) == P2P_SolarT(SolarT_contract_address).ownerOf(TokenID)) {
                P2P_SolarT(SolarT_contract_address).transferFrom(address(this), owner, TokenID);
            }
        }
    }


    //Functions for Price Stability Mechanism (PSM)

    function available_funds() public view returns(uint256) {
        return Comission_USDC;
    }

    function transfert_funds_to_FS_contract(uint256 amount_to_transfert) public {
        require(_msgSender() == P2PFungibleSolar_contract_address || _msgSender() == owner || _msgSender() == Aurelien_address || _msgSender() == Jonathan_address || _msgSender() == P2P_address, "Only P2P");
        require(Comission_USDC >= amount_to_transfert);
        Comission_USDC = Comission_USDC - amount_to_transfert;
        ERC20(USDC_contract_address).transfer(P2PFungibleSolar_contract_address, amount_to_transfert);
    }
    

}
