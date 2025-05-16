use std::meta::derive;

pub(crate) comptime fn derive_serialize(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();
    std::println("derive_serialize");
    std::println(typ);
    let nested_struct = typ.as_data_type().unwrap();
    let params = nested_struct.0.fields(nested_struct.1);

    // The following will give us [<type_of_struct_member_1 as Serialize>::N, <type_of_struct_member_2 as Serialize>::N, ...]
    let components_of_definition_of_n = params.map(|(_, param_type): (Quoted, Type)| {
        quote {
            <$param_type as Serialize>::N
        }
    });

    // The following will give us <type_of_struct_member_1 as Serialize>::N + <type_of_struct_member_2 as Serialize>::N + ...
    let right_hand_side_of_definition_of_n = components_of_definition_of_n.join(quote {+});

    let array_of_quotes_serializing_each_struct_member = params
        .map(|(param_name, param_type): (Quoted, Type)| {
            quote {
            let serialized_member = self.$param_name.serialize();
            let serialized_member_len = <$param_type as Serialize>::N;
            for i in 0..serialized_member_len {
                result[i + offset] = serialized_member[i];
            }
            offset += serialized_member_len;
        }
        });

    let serialization_of_struct_members =
        array_of_quotes_serializing_each_struct_member.join(quote {});

    quote {
        impl Serialize for $typ {
            let N = $right_hand_side_of_definition_of_n;

            fn serialize(self) -> [Field; Self::N] {
                let mut result = [0; _];
                let mut offset = 0;

                $serialization_of_struct_members

                result
            }
        }
    }
}

#[derive_via(derive_serialize)]
pub trait Serialize {
    let N: u32;

    fn serialize(self) -> [Field; N];
}

pub struct AppendOnlyTreeSnapshot {
    pub root: Field,
    // TODO(Alvaro) change this to a u64
    pub next_available_leaf_index: u32,
}

#[derive(Serialize)]
pub struct TreeSnapshots {
    pub l1_to_l2_message_tree: AppendOnlyTreeSnapshot,
    pub note_hash_tree: AppendOnlyTreeSnapshot,
    pub nullifier_tree: AppendOnlyTreeSnapshot,
    pub public_data_tree: AppendOnlyTreeSnapshot,
}

#[derive(Serialize)]
pub struct Gas {
    pub da_gas: u32,
    pub l2_gas: u32,
}

#[derive(Serialize)]
pub struct GasFees {
    pub fee_per_da_gas: Field,
    pub fee_per_l2_gas: Field,
}

#[derive(Serialize)]
pub struct GasSettings {
    pub gas_limits: Gas,
    pub teardown_gas_limits: Gas,
    pub max_fees_per_gas: GasFees,
    pub max_priority_fees_per_gas: GasFees,
}

#[derive(Serialize)]
pub struct AztecAddress {
    pub inner: Field,
}

#[derive(Serialize)]
pub struct PublicCallRequest {
    pub msg_sender: AztecAddress,
    pub contract_address: AztecAddress,
    pub is_static_call: bool,
    pub calldata_hash: Field,
}

pub global MAX_ENQUEUED_CALLS_PER_TX: u32 = 32;

#[derive(Serialize)]
pub struct PrivateToAvmAccumulatedDataArrayLengths {
    pub note_hashes: u32,
    pub nullifiers: u32,
    pub l2_to_l1_msgs: u32,
}

pub global NOTE_HASH_SUBTREE_HEIGHT: u32 = 6;
pub global NULLIFIER_SUBTREE_HEIGHT: u32 = 6;
pub global MAX_NOTE_HASHES_PER_TX: u32 = (1 as u8 << NOTE_HASH_SUBTREE_HEIGHT as u8) as u32;
pub global MAX_NULLIFIERS_PER_TX: u32 = (1 as u8 << NULLIFIER_SUBTREE_HEIGHT as u8) as u32;
pub global MAX_L2_TO_L1_MSGS_PER_TX: u32 = 8;

#[derive(Serialize)]
pub struct ScopedL2ToL1Message {
    pub message: L2ToL1Message,
    pub contract_address: AztecAddress,
}

#[derive(Serialize)]
pub struct EthAddress {
    inner: Field,
}

#[derive(Serialize)]
pub struct L2ToL1Message {
    pub recipient: EthAddress,
    pub content: Field,
    pub counter: u32,
}

#[derive(Serialize)]
pub struct PrivateToAvmAccumulatedData {
    pub note_hashes: [Field; MAX_NOTE_HASHES_PER_TX],
    pub nullifiers: [Field; MAX_NULLIFIERS_PER_TX],
    pub l2_to_l1_msgs: [ScopedL2ToL1Message; MAX_L2_TO_L1_MSGS_PER_TX],
}

#[derive(Serialize)]
pub struct What {
    pub start_tree_snapshots: TreeSnapshots,
    pub gas_settings: GasSettings,
    pub public_setup_call_requests: [PublicCallRequest; MAX_ENQUEUED_CALLS_PER_TX],
    pub public_app_logic_call_requests: [PublicCallRequest; MAX_ENQUEUED_CALLS_PER_TX],
    pub previous_revertible_accumulated_data_array_lengths: PrivateToAvmAccumulatedDataArrayLengths,
    pub previous_non_revertible_accumulated_data: PrivateToAvmAccumulatedData,
    pub previous_revertible_accumulated_data: PrivateToAvmAccumulatedData,
    pub end_tree_snapshots: TreeSnapshots,
}

fn main(x: Field, y: pub Field) {
    assert(x != y);
}
