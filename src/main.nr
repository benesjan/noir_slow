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

// When the following is commented out, the code compiles.

// impl<let O: u32> Deserialize for [Field; O] {
//     let N: u32 = <Field as Deserialize>::N * O;

//     fn deserialize(fields: [Field; Self::N]) -> Self {
//         fields
//     }
// }

// The following implementations fails to get used on line 43.
impl<let M: u32> Deserialize for [Field; M] {
    let N: u32 = <Field as Deserialize>::N * M;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        fields
    }
}

pub struct Log<let O: u32> {
    pub fields: [Field; O],
}

impl<let O: u32> Deserialize for Log<O> {
    let N: u32 = <[Field; O] as Deserialize>::N;

    // #[inline_always]
    fn deserialize(fields: [Field; Self::N]) -> Self {
        Self { fields: <[Field; O]>::deserialize(fields) }
    }
}

fn main(serialized: [Field; 10]) -> pub Field {
    let log = Log::<10>::deserialize(serialized);
    log.fields[0] // Return first field of deserialized log
}
