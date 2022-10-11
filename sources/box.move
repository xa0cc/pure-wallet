module PureHeartWallet::Box {

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, Info};
  //  use sui::string;
    use sui::transfer;
    use sui::balance;
    use sui::coin;
    use sui::vec_map::{VecMap};
    use std::signer;
    use std::vector::{Self, Vector};
    use std::string::{Self, String};
    //use movemate

    const ERR: u64 = 0;
    const MAX_U64: u64 = 18446744073709551615;

    struct Box has key, store {
        info: Info,
        owner: address,
        content: Vector<SubBox>,
        settings: VecMap<String, Vector>
    }
//settings={
//    reserve_list: Vector<address>, //vector of reserve addresses
//    password: Vector<string>,
//}
    public fun wrap(ctx: &mut TxContext, owner: address, content: Vector<SubBox>, settings: VecMap<String, Vector>): Box {
        Box { info: object::new(ctx), owner, content, settings}
    }
    spec wrap {
        ensures result.owner == owner && result.content == content;
    }

    fun access( account: &signer, box: &mut Box): (&mut Vector<SubBox>) {
        let Box {info, owner, content, settings } = box;
        assert!(owner == &(signer::address_of(account)), ERR);

        (content)
    }
    
    fun access_sub(account: &signer, box: &mut Box, subacc: u64): (&mut SubBox) {
        let SubBox = vector::borrow_mut<SubBox>(access(account, box), subacc);

        (SubBox)
    }
   
    public fun unwrap(account: &signer, box: Box): Vector<SubBox> {
        let Box {info, owner, content, settings } = box;
        assert!(owner == signer::address_of(account), ERR);

        content
    }
    spec unwrap {
        aborts_if box.owner != signer::address_of(account);
        ensures result == box.content;
    }

    public entry fun unwrap_reserve(account: &signer, box: Box, pwd: String): Vector<SubBox> {
        let Box {info, owner, content, settings } = box;
       
        let reserve_list = vec_map::get<String, Vector>(settings, string::utf8(b"reserve_list"));
        let password = *vector::borrow<String>(vec_map::get<String, Vector>(settings, string::utf8(b"password")), 0);
        assert!(pwd == password, ERR);
        assert!(vector::contains(reserve_list, &signer::address_of(account)), ERR);

        content
    }

    spec module {
        // Never abort, unless explicitly defined so:
        pragma aborts_if_is_strict;
    }

    struct SubBox has key, store {
        //coin types?? discern by types not by symbol??
        coins: VecMap<string, coin>,
        settings: VecMap<string, object>,
        journal: Journal,
        limit: VolumeLimit
    }

    // struct TransferLimit has store, drop {
    //     whitelist: Vector<address>,
    //     blacklist: Vector<address>
    // }

    struct VolumeLimit has store, drop {
        volume_per_address: VecMap<String, u64>, 
        //string or address format for addresses??
        volume_per_asset: VecMap<String, u64>
    }

//trading limits:
//market_list: Vec<string>  - just add market contract adress to whitelist?? or volume !=0
// instead of whitelist/blacklist - set volume limit for address for max/0

    struct Journal has store, drop {
        //     datetime,
        //     asset,
        //     in_out,
             info: Info,
            //  addr: address,
            //  amount: u64,
            //  txid: String
    }

// coins: (coin, balance::zero("coin")) for new wallet
    public entry fun wrap_sub(ctx: &mut TxContext, coins: VecMap<String, coin>, settings: VecMap<String, object>,limit: VolumeLimit): SubBox {
        let journal = Journal {info: object::new(ctx)};
        SubBox{ coins, settings, limit, journal}
    }

    public fun read_balance(box: &SubBox, coin: String): u64 {
      //  let SubBox { coins } = box;
        let bal =  vec_map::get<String, Coin>(box.coins, coin);

        balance::value<Coin>(bal)
    }
    
    public entry fun withdraw(box: &mut SubBox, coin: String, to: address, amount: u64, ctx: &mut TxContext) {
       // let SubBox{ coins } = box;
        assert!(balance::value<Coin>(vec_map::get<String, Coin>(&box.coins, coin)) >= amount, ERR);
        assert!(amount > fresh_limit_asset(coin, &box.journal, &box.limit), ERR);
        assert!(amount > fresh_limit_address(to, &box.journal, &box.limit), ERR);
        let bal =  vec_map::get_mut<String, Coin>(box.coins, coin);
        // let bal2 = balance::split(bal, amount);
        // let trans = coin::from_balance(bal2, ctx);
        // transfer::transfer (trans, to)   //separate func?
        coin::split_and_transfer<Coin>(bal, amount, to, ctx)
    }


    public entry fun internal_transfer(account: &signer, box: &mut Box, coin: String, from: u64, to: u64, amount: u64, ctx: &mut TxContext) {
        let sub1 = access_sub(account, box, from); 
        let sub2 = access_sub(account, box, to);
        assert!(amount > fresh_limit_asset(coin, &sub1.journal, &sub1.limit), ERR);
        assert!(coin::value<Coin>(vec_map::get<String, Coin>(sub1.coins, coin)) > amount, ERR);
        let bal_from =  vec_map::get_mut<String, Coin>(sub1.coins, coin);
        let bal_to =  vec_map::get_mut<String, Coin>(sub2.coins, coin);
      //  let trans = coin::split<Coin>(bal_from, amount, ctx);
        let c = coin::split(bal_from, amount, ctx);
        coin::join(bal_to, c)
    }

    fun parse_journal_by_symbol(journal: &Journal, symbol: String, start:u64, end:u64): u64{
        //parse info from blockchain???
        0
    }
    fun parse_journal_by_addr(journal: &Journal, addr: String, start:u64, end:u64): u64{
        0
    }

    fun fresh_limit_asset(asset: String, journal: &Journal, volumelimit: &VolumeLimit):u64 {
       //// end = timestamp_now
       //// start = end - const_24H 
        let start = 0;
        let end = 86400;
        let limit = MAX_U64;
        if (vec_map::contains<String, u64>(volumelimit.volume_per_asset, asset)){
            let set_limit = vec_map::get<String, u64>(volumelimit.volume_per_asset, asset);
            let used_limit = parse_journal_by_symbol(journal, asset, start, end);
            let limit = *set_limit  - used_limit;
        };
        limit
    }

    fun fresh_limit_address(addr: string, journal: &Journal, volumelimit: &VolumeLimit):u64 {
       //// end = timestamp_now
       ///  start = end - const_1day
        let start = 0;
        let end = 86400;
        let limit = MAX_U64;
        if (vec_map::contains<String, u64>(box.limit.volume_per_address, addr)){
            let set_limit = vec_map::get<String, u64>(volumelimit.volume_per_address, addr);
            let used_limit = parse_journal_by_addr(journal, addr, start, end);
            let limit = *set_limit - used_limit;
        };  
        limit
    }

    public entry fun edit_limits_asset(box: &mut SubBox, asset: String,  amount: u64) {
        if (vec_map::contains<String, u64>(box.limit.volume_per_asset, asset)){
            *vec_map::get_mut<String, u64>(box.limit.volume_per_asset, asset) = amount;
        } else {
            vec_map::insert(box.limit.volume_per_asset, asset, amount);
        };
    }
    public entry fun edit_limits_address(box: &mut SubBox, addr: String,  amount: u64) {
        if (vec_map::contains<String, u64>(box.limit.volume_per_address, addr)){
            *vec_map::get_mut<String, u64>(box.limit.volume_per_address, addr) = amount;
        } else {
            vec_map::insert(box.limit.volume_per_address, addr, amount)
        }
    }

///////////////////////////////
//EXAMPLES
//withdraw(access_sub(&mut Box, 1), sui, address, amount)



}

