module oft::oft_fa {

    // Ref: https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/move-examples/fungible_asset/fa_coin/sources/FACoin.move
    // Faucet: https://aptos.dev/en/network/faucet

    use std::option;
    use std::vector;
    use std::signer;
    use std::object::{Self, Object, ExtendRef};
    use std::fungible_asset::{Self, BurnRef, Metadata, MintRef};
    use std::primary_fungible_store;
    use std::string::utf8;

    const ASSET_SYMBOL: vector<u8> = b"MUSDC";
    const OFT_ADDRESS: address = @oft;

    struct OftImpl has key, store {
        store_contract_signer_extend_ref: ExtendRef,
        whitelist: vector<address>,
        mint_ref: MintRef,
        burn_ref: BurnRef,
    }

    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        let extend_ref = object::generate_extend_ref(constructor_ref);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"Mock USDC"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            6, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );
        let metadata_object_signer = object::generate_signer(constructor_ref);
        let cap_store = OftImpl {
            store_contract_signer_extend_ref: extend_ref,
            whitelist: vector::empty(),
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
        };
        move_to(&metadata_object_signer, cap_store);
    }

    #[view]
    /// Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&OFT_ADDRESS, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    inline fun store(): &OftImpl {
        let asset_address = object::create_object_address(&OFT_ADDRESS, ASSET_SYMBOL);
        borrow_global<OftImpl>(asset_address)
    }

    fun get_store_contract_signer(): signer acquires OftImpl {
        object::generate_signer_for_extending(&store().store_contract_signer_extend_ref)
    }

    public entry fun add_to_whitelist(
        account: &signer,
        whitelist_address: address
    ) acquires OftImpl {
        assert!(signer::address_of(account) == OFT_ADDRESS, 230);
        let asset_address = object::create_object_address(&OFT_ADDRESS, ASSET_SYMBOL);
        let store_mut = borrow_global_mut<OftImpl>(asset_address);
        store_mut.whitelist.push_back(whitelist_address);
    }

    #[view]
    public fun check_whitelist(account: address): bool acquires OftImpl {
        store().whitelist.contains(&account)
    }

    public entry fun mint(
        account: &signer,
        to: address,
        amount: u64
    ) acquires OftImpl {
        assert!(check_whitelist(signer::address_of(account)), 233);
        primary_fungible_store::mint(&store().mint_ref, to, amount);
    }

    public entry fun burn(
        account: &signer,
        owner: address,
        amount: u64
    ) acquires OftImpl {
        assert!(check_whitelist(signer::address_of(account)), 233);
        primary_fungible_store::burn(&store().burn_ref, owner, amount);
    }

    #[deprecated]
    public entry fun mint_use_contract_signer(
        to: address,
        amount: u64
    ) acquires OftImpl {
        mint(&get_store_contract_signer(), to, amount);
    }

    public entry fun mint_using_contract_signer(
        _account: &signer,
        to: address,
        amount: u64
    ) acquires OftImpl {
        mint(&get_store_contract_signer(), to, amount);
    }
}
