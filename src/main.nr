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

// impl<T, let M: u32> Deserialize for [T; M]
// where
//     T: Deserialize,
// {
//     let N: u32 = <T as Deserialize>::N * M;

//     fn deserialize(fields: [Field; Self::N]) -> Self {
//         let mut result: [T; M] = std::mem::zeroed();

//         for i in 0..M {
//             let mut element_fields = [0; <T as Deserialize>::N];
//             for j in 0..<T as Deserialize>::N {
//                 element_fields[j] = fields[i * <T as Deserialize>::N + j];
//             }
//             result[i] = T::deserialize(element_fields);
//         }

//         result
//     }
// }

impl<let M: u32> Deserialize for [Field; M] {
    let N: u32 = <Field as Deserialize>::N * M;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        // let mut result: [Field; M] = std::mem::zeroed();
        // for i in 0..M {
        //     let mut element_fields = [0; <Field as Deserialize>::N];
        //     for j in 0..<Field as Deserialize>::N {
        //         element_fields[j] = fields[i * <Field as Deserialize>::N + j];
        //     }
        //     result[i] = Field::deserialize(element_fields);
        // }
        // result
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
