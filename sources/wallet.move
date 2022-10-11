module PureHeartWallet::Wallet {
    use std::signer;
    use std::vector;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Info};
    use std::string::String;
    use sui::transfer;

    //use TaoHe;
    use PureHeartWallet::Box;


    struct CreatorCapability has key, store {
            info: Info
        }
    struct UserCapability has key, store {
            info: Info
        }
    struct Capability has key, store {
            info: Info
        }

    fun initialize(ctx: &mut TxContext) {
            transfer::transfer(CreatorCapability {
                info: object::new(ctx),
            }, tx_context::sender(ctx))
        }
    }