pub trait Deserialize {
    let N: u32;

    fn deserialize(fields: [Field; N]) -> Self;
}

impl Deserialize for Field {
    let N: u32 = 1;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        fields[0]
    }
}

#[oracle(loadCapsule)]
unconstrained fn load_oracle<let N: u32>(
    contract_address: Field,
    slot: Field,
    array_len: u32,
) -> Option<[Field; N]> {}

/// Returns data previously stored via `storeCapsule` in the per-contract non-volatile database. Returns Option::none() if
/// nothing was stored at the given slot.
pub unconstrained fn load<T>(contract_address: Field, slot: Field) -> Option<T>
where
    T: Deserialize,
{
    let serialized_option = load_oracle(contract_address, slot, <T as Deserialize>::N);
    serialized_option.map(|arr| Deserialize::deserialize(arr))
}

pub(crate) struct TestStruct {
    pub value1: Field,
    pub value2: Field,
    pub value3: Field,
}

impl Deserialize for TestStruct {
    let N: u32 = 3;
    fn deserialize(fields: [Field; Self::N]) -> Self {
        Self { value1: fields[0], value2: fields[1], value3: fields[2] }
    }
}

fn main(address: Field, slot: Field) -> pub (Field, Field, Field) {
    let value = unsafe { load::<TestStruct>(address, slot) }.unwrap();
    let value2 = unsafe { load::<Field>(address, 6) }.unwrap();

    (value.value1, value.value2, value2)
}
