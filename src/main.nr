use std::meta::derive;

#[derive_via(derive_serialize)]
pub trait Serialize {
    let N: u32;

    fn serialize(self) -> [Field; N];
}

pub comptime fn derive_serialize(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();
    let nested_struct = typ.as_data_type().unwrap();
    let params = nested_struct.0.fields(nested_struct.1);

    // The following will give us [<type_of_struct_member_1 as Serialize>::N, <type_of_struct_member_2 as Serialize>::N, ...]
    let components_of_definition_of_n = params.map(|(_, param_type, _): (Quoted, Type, Quoted)| {
        quote {
            <$param_type as Serialize>::N
        }
    });

    // The following will give us <type_of_struct_member_1 as Serialize>::N + <type_of_struct_member_2 as Serialize>::N + ...
    let right_hand_side_of_definition_of_n = components_of_definition_of_n.join(quote {+});

    let array_of_quotes_serializing_each_struct_member = params
        .map(|(param_name, param_type, _): (Quoted, Type, Quoted)| {
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
            let N: u32 = $right_hand_side_of_definition_of_n;

            #[inline_always]
            fn serialize(self) -> [Field; Self::N] {
                let mut result = [0; _];
                let mut offset = 0;

                $serialization_of_struct_members

                result
            }
        }
    }
}

impl Serialize for bool {
    let N: u32 = 1;

    fn serialize(self) -> [Field; Self::N] {
        [self as Field]
    }
}

impl Serialize for u32 {
    let N: u32 = 1;

    fn serialize(self) -> [Field; Self::N] {
        [self as Field]
    }
}

impl Serialize for Field {
    let N: u32 = 1;

    fn serialize(self) -> [Field; Self::N] {
        [self]
    }
}

impl<T, let N: u32> Serialize for [T; N]
where
    T: Serialize,
{
    let N: u32 = <T as Serialize>::N * N;

    fn serialize(self) -> [Field; Self::N] {
        let mut result: [Field; _] = std::mem::zeroed();
        for i in 0..N {
            let serialized_t = self[i].serialize();
            for j in 0..<T as Serialize>::N {
                result[i * <T as Serialize>::N + j] = serialized_t[j];
            }
        }
        result
    }
}

#[derive(Serialize)]
pub struct PrivateToAvmAccumulatedDataArrayLengths {
    pub note_hashes: u32,
    pub nullifiers: u32,
    pub l2_to_l1_msgs: u32,
}

#[derive(Serialize)]
pub struct EthAddress {
    inner: Field,
}

#[derive(Serialize)]
pub struct AztecAddress {
    pub inner: Field,
}

#[derive(Serialize)]
pub struct L2ToL1Message {
    pub recipient: EthAddress,
    pub content: Field,
}

pub struct Scoped<T> {
    pub inner: T,
    pub contract_address: AztecAddress,
}

impl<T> Serialize for Scoped<T>
where
    T: Serialize,
{
    let N: u32 = <T as Serialize>::N + 1;

    fn serialize(self) -> [Field; Self::N] {
        self.inner.serialize().concat([self.contract_address.to_field()])
    }
}

pub global MAX_NOTE_HASHES_PER_TX: u32 = 64;
pub global MAX_NULLIFIERS_PER_TX: u32 = 64;
pub global MAX_L2_TO_L1_MSGS_PER_TX: u32 = 8;
pub global PUBLIC_LOG_SIZE_IN_FIELDS: u32 = 13;
pub global MAX_PUBLIC_LOGS_PER_TX: u32 = 8;
pub global MAX_TOTAL_PUBLIC_DATA_UPDATE_REQUESTS_PER_TX: u32 = 64;

#[derive(Serialize)]
pub struct PrivateToAvmAccumulatedData {
    pub note_hashes: [Field; MAX_NOTE_HASHES_PER_TX],
    pub nullifiers: [Field; MAX_NULLIFIERS_PER_TX],
    pub l2_to_l1_msgs: [Scoped<L2ToL1Message>; MAX_L2_TO_L1_MSGS_PER_TX],
}

pub struct Log<let N: u32> {
    pub fields: [Field; N],
    // The actual length (number of fields) of the log to be included in the blobs.
    pub length: u32,
}

impl<let N: u32> Serialize for Log<N> {
    let N: u32 = N + 1; // +1 for length field

    #[inline_always]
    fn serialize(self) -> [Field; Self::N] {
        let mut result = [0; Self::N];

        // Copy log fields
        for i in 0..N {
            result[i] = self.fields[i];
        }

        // Store length as last field
        result[N] = self.length as Field;

        result
    }
}

#[derive(Serialize)]
pub struct PublicDataWrite {
    pub leaf_slot: Field,
    pub value: Field,
}

#[derive(Serialize)]
pub struct PublicLog {
    pub log: Log<PUBLIC_LOG_SIZE_IN_FIELDS>,
    pub contract_address: AztecAddress,
}

#[derive(Serialize)]
pub struct AvmAccumulatedData {
    // The note hashes from private combining with those made in the AVM execution.
    pub note_hashes: [Field; MAX_NOTE_HASHES_PER_TX],
    // The nullifiers from private combining with those made in the AVM execution.
    pub nullifiers: [Field; MAX_NULLIFIERS_PER_TX],
    // The L2 to L1 messages from private combining with those made in the AVM execution.
    pub l2_to_l1_msgs: [Scoped<L2ToL1Message>; MAX_L2_TO_L1_MSGS_PER_TX],
    // The public logs emitted from the AVM execution.
    pub public_logs: [PublicLog; MAX_PUBLIC_LOGS_PER_TX],
    // The public data writes made in the AVM execution.
    pub public_data_writes: [PublicDataWrite; MAX_TOTAL_PUBLIC_DATA_UPDATE_REQUESTS_PER_TX],
}

#[derive(Serialize)]
pub struct AvmCircuitPublicInputs {
    pub previous_revertible_accumulated_data_array_lengths: PrivateToAvmAccumulatedDataArrayLengths,
    pub previous_non_revertible_accumulated_data: PrivateToAvmAccumulatedData,
    pub previous_revertible_accumulated_data: PrivateToAvmAccumulatedData,

    ///////////////////////////////////
    // Outputs.
    pub accumulated_data: AvmAccumulatedData,
    pub reverted: bool,
}

fn main(x: Field, y: pub Field) {
    assert(x != y);
}
