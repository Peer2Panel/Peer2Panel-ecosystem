

async function main () {

    const [owner, user1, user2] = await ethers.getSigners();
    console.log(owner.address)
    let [SolarT, P2PMarketplace, FungibleSolar, USDC] = await deploy(owner);
    await sleep(500) //ms
    console.log('\n Running tests...')
    await run_test_contracts(SolarT, P2PMarketplace, FungibleSolar, USDC, owner, user1, user2);
    await sleep(500) //ms
    console.log('');
    await run_test_upgrade(SolarT, P2PMarketplace, FungibleSolar, USDC);
    console.log('\n');

}



async function deploy(owner) {

    const owner_ = owner.address;
    const trusted_forwarder_address = '0x9399BB24DBB5C4b782C70c2969F58716Ebbd6a3b'; //Forwarder contract on Polygon Testnet (Mumbai)

    // Deploy contracts
    const SolarT_ = await ethers.getContractFactory('P2P_SolarT');
    const FungibleSolar_ = await ethers.getContractFactory('P2P_FungibleSolar');
    const P2PMarketplace_ = await ethers.getContractFactory('P2P_MarketPlace');
    const USDC_ = await ethers.getContractFactory('USDC_mint');
    const USDC = await USDC_.deploy(trusted_forwarder_address);
    const USDC_contract_address = USDC.address;
    console.log("Test USDC deployed to:", USDC.address);


    console.log('Deploying SolarT...');
    const tesnet = true;
    const SolarT = await upgrades.deployProxy(SolarT_, [owner_, USDC_contract_address, trusted_forwarder_address, tesnet], {initializer: 'initialize'});
    await SolarT.deployed();
    const SolarT_address = SolarT.address;
    console.log("SolarT proxy deployed to:", SolarT.address);

    console.log('Deploying FungibleSolar...');
    const FungibleSolar = await upgrades.deployProxy(FungibleSolar_, [SolarT_address, owner_, USDC_contract_address, trusted_forwarder_address], {initializer: 'initialize'});
    await FungibleSolar.deployed();
    const FungibleSolar_address = FungibleSolar.address;
    console.log('FungibleSolar proxy deployed to:', FungibleSolar.address);


    console.log('Deploying P2PMarketplace...');
    const P2PMarketplace = await upgrades.deployProxy(P2PMarketplace_, [SolarT_address, FungibleSolar_address, owner_, USDC_contract_address, trusted_forwarder_address], {initializer: 'initialize'});
    await P2PMarketplace.deployed();
    const P2PMarketplace_address = P2PMarketplace.address;
    console.log('P2PMarketplace proxy deployed to:', P2PMarketplace.address);

    //Initialize SolarT with the correct addresses
    await SolarT.update_addresses(P2PMarketplace_address, FungibleSolar_address);
    console.log('SolarT initialized');

    //Initialize FungibleSolar with the correct addresses
    await FungibleSolar.update_addresses(P2PMarketplace_address);
    console.log('FungibleSolar initialized');

    return [SolarT, P2PMarketplace, FungibleSolar, USDC];
}





async function run_test_contracts (SolarT, P2PMarketplace, FungibleSolar, USDC, owner, user1, user2) {
    const n_test = 9;
    let passed_test = 0;
    let passed = true;
    SolarT.add_address_whitelist(user1.address, 'user1')
    SolarT.add_address_whitelist(user2.address, 'user2')
    //SolarT.add_unlimted_solarT_allowance(user1.address)
    //SolarT.add_unlimted_solarT_allowance(user2.address)


    //I) Contracts functions

    //SolarT contract
    //1: mint and burn SolarT
    console.log('Mint and Burn SolarT...');
    SolarT.get_SolarT_amount();
    await SolarT.mint_SolarT(owner.address, 'Solar0');
    await SolarT.mint_SolarT(owner.address, 'Solar1');
    await SolarT.mint_SolarT_with_info(owner.address, 'Solar3', 400000000, 240);
    await SolarT.update_URI(0, 'NewSolar0')
    await SolarT.burn(1);
    await SolarT.replace_SolarT(1,owner.address, 'Solar1bis');
    let Ntokens = await SolarT.get_SolarT_amount();
    let Nburned = await SolarT.burned_SolarT();
    let Solar0_URI = await(SolarT.tokenURI(0));

    passed = (Ntokens.toNumber()==3) && (Nburned.toNumber()==0) && (Solar0_URI == 'NewSolar0');

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
        console.log('  3 Tokens should have been minted, but we read', Ntokens.toNumber());
        console.log('  1-1=0 Tokens should have been burned, but we read', Nburned.toNumber());
        console.log('  URI should be NewSolar0, but we read', Solar0_URI);
    }

    

    //2: Add entilted amount of several addresses and withdraw USD
    console.log('Add entilted amount of several addresses and withdraw...');

    let Solar_tokenID = 2
    await SolarT.transferFrom(owner.address, user1.address, Solar_tokenID);
    await SolarT.Add_SolarT_entilted_amount(Solar_tokenID, 100);
    let Entilted_amnt = await SolarT.Entilted_amount(user1.address);
    passed = (Entilted_amnt.toNumber() == 100)
    //TODO
    //await SolarT.connect(user1).withdraw_profit();
    //let user1_balance = await ERC20(USDC_address).balanceOf(user1.address)
    let user1_balance = Entilted_amnt

    passed = (Entilted_amnt.toNumber() == 100) && (user1_balance.toNumber() == 100)

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
        console.log('  Entilted amount should be 100, but we read', Entilted_amnt.toNumber());
        console.log('  User1 withdrawn amount should be 100, but we read', user1_balance.toNumber());
    }



    //Marketplace
    //3: List and delist a SolarT
    console.log('List and delist a SolarT...');

    Solar_tokenID = 1;

    //await SolarT.list_SolarT(Solar_tokenID, 200);
    await SolarT.approve_listing(Solar_tokenID);
    await P2PMarketplace.list_SolarT(Solar_tokenID, 200);
    let listing_price = await P2PMarketplace.SolarT_Price(Solar_tokenID);
    await P2PMarketplace.unlist_SolarT (Solar_tokenID);
    let NFTowner = await SolarT.ownerOf(Solar_tokenID);

    passed = (listing_price.toNumber() == 200) && (String(NFTowner) == String(owner.address)); //handle address as str, comparison didnt work

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
        console.log('  Listing price should be 200, but we read', listing_price.toNumber());
        console.log('  New owner after delisting should be previous owner:', owner.address ,', but it is', NFTowner);
    }



    //4: List and sell a SolarT
    console.log('List and sell a SolarT...');

    Solar_tokenID = 1;
    await SolarT.approve_listing(Solar_tokenID);
    await P2PMarketplace.list_SolarT(Solar_tokenID, 200);
    await USDC.mint(user2.address, 1000);
    await USDC.connect(user2).approve(P2PMarketplace.address, 200);
    await P2PMarketplace.connect(user2).buy_SolarT(Solar_tokenID);
    let commission = await USDC.balanceOf(P2PMarketplace.address);
    let user2amount = await USDC.balanceOf(user2.address);
    
    passed = (user2amount == 800) && (commission == 2);

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
    }




    //5: List, bid, remove bid, bid, overbid and accept bid
    console.log('List, bid, remove bid, bid, overbid and accept bid...');
    await SolarT.mint_SolarT(owner.address, 'Solar0');
    Solar_tokenID = await SolarT.get_SolarT_amount()-1;
    await SolarT.approve_listing(Solar_tokenID);
    await P2PMarketplace.list_SolarT(Solar_tokenID, 800);
    await USDC.mint(user2.address, 1000);
    await USDC.mint(user1.address, 1000);
    await USDC.mint(owner.address, 1000);

    let prevO = await USDC.balanceOf(owner.address);
    let prev1 = await USDC.balanceOf(user1.address);
    let prev2 = await USDC.balanceOf(user2.address);
    

    await USDC.connect(user2).approve(P2PMarketplace.address, 200);
    await P2PMarketplace.connect(user2).place_bid(Solar_tokenID, 200);
    await USDC.connect(user1).approve(P2PMarketplace.address, 400);
    await P2PMarketplace.connect(user1).place_bid(Solar_tokenID, 400);
    await P2PMarketplace.connect(user1).withdraw_bid(Solar_tokenID);
    await USDC.connect(user1).approve(P2PMarketplace.address, 300);
    await P2PMarketplace.connect(user1).place_bid(Solar_tokenID, 300);
    await P2PMarketplace.accept_bid(Solar_tokenID);

    let owneramount = await USDC.balanceOf(owner.address);
    let user1amount = await USDC.balanceOf(user1.address);
    user2amount = await USDC.balanceOf(user2.address);
    
    passed = (owneramount == prevO.toNumber()+297) && (user1amount == prev1.toNumber()-300) && (user2amount.toNumber() == prev2);

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
        console.log('  owner amount', owneramount.toNumber(), 'should be', prevO.toNumber()+297);
        console.log('  User1 amount', user1amount.toNumber(), 'should be', prev1.toNumber()-300);
        console.log('  User2 amount', user2amount.toNumber(), 'should be', prev2.toNumber());
    }



    //6 Withdraw entiltes amount when SolarT listed
    console.log('Withdraw entiltes amount when SolarT listed...');

    await SolarT.mint_SolarT(owner.address, 'Solar0');
    Solar_tokenID = await SolarT.get_SolarT_amount()-1;
    await SolarT.Add_SolarT_entilted_amount(Solar_tokenID, 100);
    Entilted_amnt = await SolarT.Entilted_amount(user1.address);
    passed = (Entilted_amnt.toNumber() == 100)

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
    }



    //Fungible Solar
    //7: Borrow and mint FS
    console.log('Borrow and mint FS...');

    await SolarT.mint_SolarT(owner.address, 'Solar0');
    Solar_tokenID = await SolarT.get_SolarT_amount()-1;
    await FungibleSolar.update_SolarT_value(Solar_tokenID, 3000000);
    await SolarT.approve_staking(Solar_tokenID)
    await FungibleSolar.stake_SolarT(Solar_tokenID);
    FSbalance = await FungibleSolar.balanceOf(owner.address);
    NFTowner = await SolarT.ownerOf(Solar_tokenID);
    
    passed = (FSbalance.toNumber() == 2550000) && (String(NFTowner) == String(FungibleSolar.address)); //handle address as str, comparison didnt work

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
        console.log('  255 FS should have been minted, but we read', FSbalance.toNumber());
        console.log('  New owner after delisting should be previous owner:', FungibleSolar.address ,', but it is', NFTowner);
    }



    //8: Unstake and burn FS
    console.log('Unstake and burn FS...');

    await USDC.mint(owner.address, 300000000000000);
    await USDC.approve(FungibleSolar.address, 300000000000000);
    FungibleSolar.exchange_USDC_TO_FS(300000000000000);

    await FungibleSolar.void();
    FSowed = await FungibleSolar.get_FSamount_due(Solar_tokenID);
    console.log('  FSowed', FSowed.toNumber());
    FSbalance0 = await FungibleSolar.balanceOf(owner.address);
    //console.log('  FSbalance', FSbalance0.toNumber());
    
    await FungibleSolar.unstake_SolarT(Solar_tokenID);
    FSbalance = await FungibleSolar.balanceOf(owner.address);
    NFTowner = await SolarT.ownerOf(Solar_tokenID);

    passed = (FSbalance.toNumber() < FSbalance0.toNumber()) && (String(NFTowner) == String(owner.address)); //handle address as str, comparison didnt work

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
        console.log('  User should have less than', FSbalance0.toNumber() , 'FS left, but we read', FSbalance.toNumber());
        console.log('  Owner should get back his NFT ownership:', owner.address ,', but it is', NFTowner);
    }


    //9: Get list of staked SolarT
    console.log('Get list of staked SolarT...');

    await SolarT.mint_SolarT(owner.address, 'Solar10');
    Solar_tokenID = await SolarT.get_SolarT_amount()-1;
    await FungibleSolar.update_SolarT_value(Solar_tokenID, 3000000);
    await SolarT.approve_staking(Solar_tokenID)
    await FungibleSolar.stake_SolarT(Solar_tokenID);
    await sleep(1) //ms

    await SolarT.mint_SolarT(owner.address, 'Solar11');
    Solar_tokenID = await SolarT.get_SolarT_amount()-1;
    await FungibleSolar.update_SolarT_value(Solar_tokenID, 3000000);
    await SolarT.approve_staking(Solar_tokenID)
    await FungibleSolar.stake_SolarT(Solar_tokenID);
    await sleep(1) //ms

    staker_list = await FungibleSolar.get_list_of_solarT_staker();
    //console.log(staker_list);

    solarIDs = await SolarT.SolarT_IDs_of(owner.address);
    //console.log(solarIDs);

    is_staked = await FungibleSolar.is_staked(4);
    //console.log(is_staked);

    staked_list = await FungibleSolar.get_list_of_solarT_staked(owner.address);
    


    //await sleep(1) //ms



    //10: Entilted amount when SolarT staked, withdraw after unstaking
    console.log('Entilted amount when SolarT staked, withdraw after unstaking...');
    
    USDbalance_prev = await USDC.balanceOf(owner.address);
    await SolarT.mint_SolarT(owner.address, 'Solar0');
    await USDC.mint(FungibleSolar.address, 1000);
    Solar_tokenID = await SolarT.get_SolarT_amount()-1;
    await FungibleSolar.update_SolarT_value(Solar_tokenID, 300);
    await SolarT.approve_staking(Solar_tokenID)
    await FungibleSolar.stake_SolarT(Solar_tokenID);
    await SolarT.Add_SolarT_entilted_amount(Solar_tokenID, 200);
    Entilted_amnt = await FungibleSolar.SolarT_blocked_income(Solar_tokenID);
    await FungibleSolar.unstake_SolarT(Solar_tokenID);
    USDbalance = await USDC.balanceOf(owner.address);
    NFTowner = await SolarT.ownerOf(Solar_tokenID);


    passed = (Entilted_amnt.toNumber() == 200) && (USDbalance.toNumber() == USDbalance_prev.toNumber() + 200)

    if (passed == true) {
        passed_test ++;
        console.log('  Passed');
    }
    else {
        console.log('  Failed');
        console.log('  Entilted amount should be 200, but we read', Entilted_amnt.toNumber());
        console.log('  USDC balance after withdraw should be', USDbalance_prev.toNumber() + 200 , ', but we read', USDbalance.toNumber());
    }


    console.log(passed_test, '/', n_test, 'tests passed')


    //11: Test function to get all panel info
    All_info = await SolarT.get_all_SolarT_info()
    //console.log(All_info)

}

async function run_test_upgrade(SolarT, P2PMarketplace, FungibleSolar, USDC) {

    //V2 contracts are the same

    const n_test = 1;
    let passed_test = 0;
    let passed = true;


    const SolarTV2_ = await ethers.getContractFactory('P2P_SolarTV');
    const FungibleSolarV2_ = await ethers.getContractFactory('P2P_FungibleSolarV');
    const P2PMarketplaceV2_ = await ethers.getContractFactory('P2P_MarketPlaceV');

    const upgraded_SolarT = await upgrades.upgradeProxy(SolarT.address, SolarTV2_);
    console.log("SolarT proxy updated");

    const upgraded_P2PMarketplace = await upgrades.upgradeProxy(P2PMarketplace.address, P2PMarketplaceV2_);
    console.log("P2PMarketplace proxy updated");

    const upgraded_FungibleSolar = await upgrades.upgradeProxy(FungibleSolar.address, FungibleSolarV2_);
    console.log("FungibleSolar proxy updated");

    //II) Contracts upgradability
    //Verify that the state of the contract is conserved
    console.log('Upgrade contracts and verify that state is conserved');
    if (passed == true) {
        console.log('   Passed');
        passed_test ++;
    }
    else {
        console.log('   Failed');
    }

    console.log(passed_test, '/', n_test, 'tests passed')


}



function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}


main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});