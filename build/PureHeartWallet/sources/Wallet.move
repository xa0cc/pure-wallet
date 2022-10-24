module PureHeartWallet::Wallet {
    use std::signer;
    use std::vector;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use std::string::String;
    use sui::transfer;

    //use TaoHe;
    use PureHeartWallet::Box;


    struct CreatorCapability has key, store {
            ID: UID
        }
    struct UserCapability has key, store {
            ID: UID
        }
    struct Capability has key, store {
            ID: UID
        }

    fun initialize(ctx: &mut TxContext) {
            transfer::transfer(CreatorCapability {
                ID: object::new(ctx),
            }, tx_context::sender(ctx))
        }
    }