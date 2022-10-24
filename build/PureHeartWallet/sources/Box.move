module PureHeartWallet::Box {

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
  //  use sui::string;
  //  use sui::transfer;
    use sui::balance;
    use sui::coin::{Self, Coin};
    use sui::vec_map::{Self, VecMap};
    use sui::pay;
  //  use std::option::{Self, Option};
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::ascii;
    use std::bcs;
    //use movemate

    const ERR: u64 = 0;
    const MAX_U64: u64 = 18446744073709551615;

    struct Box<T1, T2> has key, store {
        id: UID,
        owner: address,
        content: vector<SubBox<T1, T2>>,
        settings: VecMap<String, vector<String>>
    }
//settings={
//    reserve_list: vector<string>, //vector of reserve addresses
//    password: vector<string>,
//}
    public fun wrap<T1, T2>(ctx: &mut TxContext, owner: address, content: vector<SubBox<T1, T2>>, settings: VecMap<String, vector<String>>): Box<T1, T2> {
        Box {id: object::new(ctx), owner, content, settings}
    }
    // spec wrap {
    //     ensures result.owner == owner && result.content == content;
    // }

    fun access<T1, T2>(account: &signer, box: &mut Box<T1, T2>): (&mut vector<SubBox<T1, T2>>) {
      //  let Box {id, owner, content, settings } = box;
        assert!(&box.owner == &(signer::address_of(account)), ERR);

        &mut box.content
    }
    fun read<T1, T2>(account: &signer, box: &Box<T1, T2>): (&vector<SubBox<T1, T2>>) {
      //  let Box {id, owner, content, settings } = box;
        assert!(&box.owner == &(signer::address_of(account)), ERR);

        & box.content
    }
    
    fun access_sub<T1, T2>(account: &signer, box: &mut Box<T1, T2>, subacc: u64): (&mut SubBox<T1, T2>) {
        let subbox = vector::borrow_mut<SubBox<T1, T2>>(access(account, box), subacc);

        subbox
    }
    fun read_sub<T1, T2>(account: &signer, box: &Box<T1, T2>, subacc: u64): (&SubBox<T1, T2>) {
        let subbox = vector::borrow<SubBox<T1, T2>>(read(account, box), subacc);

        subbox
    }

    fun unpack_sub<T1, T2>(account: &signer, box: &mut Box<T1, T2>, subacc: u64): (SubBox<T1, T2>) {
        let subbox = vector::remove<SubBox<T1, T2>>(access(account, box), subacc);

        subbox
    }
   
    public fun unwrap<T1, T2>(account: &signer, box: Box<T1, T2>): (UID, vector<SubBox<T1, T2>>, VecMap<String, vector<String>>) {
        let Box {id, owner, content, settings} = box;
        assert!(&owner == &signer::address_of(account), ERR);

        (id, content, settings)
    }

    public entry fun unwrap_reserve<T1, T2>(account: &signer, box: Box<T1, T2>, pwd: String): (UID, vector<SubBox<T1, T2>>, VecMap<String, vector<String>>)  {
        let Box {id, owner, content, settings } = box;
        let reserve_list = vec_map::get<String, vector<String>>(&mut settings, &string::utf8(b"reserve_list"));
        let password = *vector::borrow<String>(vec_map::get<String, vector<String>>(&mut settings, &string::utf8(b"password")), 0);
        assert!(pwd == password, ERR);
        assert!(vector::contains(reserve_list, &string::utf8(bcs::to_bytes(&signer::address_of(account)))), ERR);

        (id, content, settings)
    }

    spec module {
        // Never abort, unless explicitly defined so:
        pragma aborts_if_is_strict;
    }

    struct SubBox<T1, T2> has key, store {
        coin1: Coin<T1>,
        coin2: Coin<T2>,
        settings: VecMap<String, vector<String>>,
        journal: Journal,
        limit: VolumeLimit
    }

    // struct TransferLimit has store, drop {
    //     whitelist: vector<address>,
    //     blacklist: vector<address>
    // }

    struct VolumeLimit has store, drop {
        volume_per_address: VecMap<String, u64>, 
        //string or address format for addresses??
        volume_per_coin: VecMap<String, u64>
    }

//trading limits:
//market_list: Vec<string>  - just add market contract adress to whitelist?? or volume !=0
// instead of whitelist/blacklist - set volume limit for address for max/0

    struct Journal has store {
        //     datetime,
        //     coin,
        //     in_out,
            // //  addr: address,
            //   amount: u64,
            //   txid: String,
              id: UID}

// coins: (coin, balance::zero("coin")) for new wallet
    public entry fun wrap_sub<T1, T2>(ctx: &mut TxContext, coin1: Coin<T1>,coin2: Coin<T2>, settings: VecMap<String, vector<String>>,limit: VolumeLimit): SubBox<T1, T2> {
        let journal = Journal {id: object::new(ctx)};
        SubBox{ coin1, coin2, settings, limit, journal}
    }

    public fun read_balance<T1, T2>(box: &SubBox<T1, T2>, coin: String): u64 {
        let summ = 0;
        if(coin == string::utf8(b"1")){
            let bal =  &box.coin1;
            let summ = coin::value(bal);
        } else {
            let bal =  &box.coin2;
            let summ = coin::value(bal);
        };

        summ
    }
    
    public entry fun withdraw<T1, T2>(box: &mut SubBox<T1, T2>, coin: String, to: address, amount: u64, ctx: &mut TxContext) {
        assert!(amount > fresh_limit_coin(coin, &box.journal, &box.limit), ERR);
        assert!(amount > fresh_limit_address(string::utf8(bcs::to_bytes(&to)), &box.journal, &box.limit), ERR);
        if(coin == string::utf8(b"1")){
            assert!(coin::value<T1>(&box.coin1) >= amount, ERR);
            pay::split_and_transfer<T1>(&mut box.coin1, amount, to, ctx);
        } else if(coin == string::utf8(b"2")){
            assert!(coin::value<T2>(&box.coin2) >= amount, ERR);
            pay::split_and_transfer<T2>(&mut box.coin2, amount, to, ctx);
        }
    }

    public entry fun take_from_sub_1<T1, T2>(subbox: &mut SubBox<T1, T2>, amount: u64, ctx: &mut TxContext): Coin<T1>{
        assert!(amount > fresh_limit_coin(string::utf8(b"1"), &subbox.journal, &subbox.limit), ERR);
        /// 0 address in limit for taking out coins in program
        assert!(amount > fresh_limit_address(string::utf8(b"0"), &subbox.journal, &subbox.limit), ERR);
        assert!(coin::value<T1>(&subbox.coin1) >= amount, ERR);
        coin::split<T1>(&mut subbox.coin1, amount, ctx)
    }
    public entry fun take_from_sub_2<T1, T2>(subbox: &mut SubBox<T1, T2>, amount: u64, ctx: &mut TxContext): Coin<T2>{
        assert!(amount > fresh_limit_coin(string::utf8(b"2"), &subbox.journal, &subbox.limit), ERR);
        assert!(amount > fresh_limit_address(string::utf8(b"0"), &subbox.journal, &subbox.limit), ERR);
        assert!(coin::value<T2>(&subbox.coin2) >= amount, ERR);
        coin::split<T2>(&mut subbox.coin2, amount, ctx)
    }
    public entry fun put_in_sub_1<T1, T2>(subbox: &mut SubBox<T1, T2>, coins: Coin<T1>){
        coin::put<T1>(coin::balance_mut<T1>(&mut subbox.coin1), coins);
    }
    public entry fun put_in_sub_2<T1, T2>(subbox: &mut SubBox<T1, T2>, coins: Coin<T2>){
        coin::put<T2>(coin::balance_mut<T2>(&mut subbox.coin2), coins);
    }
    
/*     public entry fun internal_transfer<T1, T2>(account: &signer, box: &mut Box<T1, T2>, coin: String, from: u64, to: u64, amount: u64, ctx: &mut TxContext) {
        let sub1 =  access_sub<T1, T2>(account, box, from);
        assert!(amount > fresh_limit_coin(coin, &sub1.journal, &sub1.limit), ERR);
        if(coin == string::utf8(b"1")) {
            assert!(coin::value<T1>(&sub1.coin1) > amount, ERR);
            let c = coin::split<T1>(&mut sub1.coin1, amount, ctx);
            pay::join<T1>(&mut sub2.coin1, c);
        } else if(coin == string::utf8(b"2")) {
            assert!(coin::value<T2>(&sub1.coin2) > amount, ERR);
            let c = coin::split<T2>(&mut sub1.coin2, amount, ctx);
            pay::join<T2>(&mut sub2.coin2, c);
        };
    } */
    public entry fun internal_transfer<T1, T2>(account: &signer, box: &mut Box<T1, T2>, coin: String, from: u64, to: u64, amount: u64, ctx: &mut TxContext) {
      //  assert!(amount > fresh_limit_coin(coin, &read_sub<T1, T2>(account, &box, from).journal, &read_sub<T1, T2>(account, &box, from).limit), ERR);
        if(coin == string::utf8(b"1")) {
            let c = take_from_sub_1<T1, T2>(access_sub<T1, T2>(account, box, from), amount, ctx);
            put_in_sub_1<T1, T2>(access_sub<T1, T2>(account, box, to), c);
        } else if (coin == string::utf8(b"2")) {
            let c = take_from_sub_2<T1, T2>(access_sub<T1, T2>(account, box, from), amount, ctx);
            put_in_sub_2<T1, T2>(access_sub<T1, T2>(account, box, to), c);
        }
    }

    fun parse_journal_by_symbol(journal: &Journal, symbol: String, start:u64, end:u64): u64{
        0
    }
    fun parse_journal_by_addr(journal: &Journal, addr: String, start:u64, end:u64): u64{
        0
    }

    fun fresh_limit_coin(coin: String, journal: &Journal, volumelimit: &VolumeLimit):u64 {
       //// end = timestamp_now
       //// start = end - const_24H 
        let start = 0;
        let end = 86400;
        let limit = MAX_U64;
        if (vec_map::contains<String, u64>(&volumelimit.volume_per_coin, &coin)){
            let set_limit = vec_map::get<String, u64>(&volumelimit.volume_per_coin, &coin);
            let used_limit = parse_journal_by_symbol(journal, copy coin, start, end);
            let limit = *set_limit  - used_limit;
        };
        limit
    }

    fun fresh_limit_address(addr: String, journal: &Journal, volumelimit: &VolumeLimit):u64 {
       // end = timestamp_now
       //  start = end - const_24H
        let start = 0;
        let end = 86400;
        let limit = MAX_U64;
        if (vec_map::contains<String, u64>(&volumelimit.volume_per_address, &addr)){
            let set_limit = vec_map::get<String, u64>(&volumelimit.volume_per_address, &addr);
            let used_limit = parse_journal_by_addr(journal, copy addr, start, end);
            let limit = *set_limit - used_limit;
        };  
        limit
    }

    public entry fun edit_limits_coin<T1, T2>(box: &mut SubBox<T1, T2>, coin: String,  amount: u64) {
        if (vec_map::contains<String, u64>(&box.limit.volume_per_coin, &coin)){
            *vec_map::get_mut<String, u64>(&mut box.limit.volume_per_coin, &coin) = amount;
        } else {
            vec_map::insert(&mut box.limit.volume_per_coin, coin, amount);
        };
    }

    public entry fun edit_limits_address<T1, T2>(box: &mut SubBox<T1, T2>, addr: String,  amount: u64) {
        if (vec_map::contains<String, u64>(&box.limit.volume_per_address, &addr)){
            *vec_map::get_mut<String, u64>(&mut box.limit.volume_per_address, &addr) = amount;
        } else {
            vec_map::insert(&mut box.limit.volume_per_address, addr, amount)
        };
    }

///////////////////////////////
//EXAMPLES
//withdraw(access_sub(&mut Box, 1), sui, address, amount)
}

