#[derive_via(derive_deserialize)]
pub trait Deserialize {
    let N: u32;

    fn deserialize(fields: [Field; N]) -> Self;
}

pub(crate) comptime fn derive_deserialize(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();

    quote {
        impl<let O: u32> Deserialize for $typ {
            let N: u32 = <[Field; O] as Deserialize >::N;

            #[inline_always]
            fn deserialize(serialized: [Field; Self::N]) -> Self {
                let mut offset = 0;

                let mut member_fields = [0; <[Field; O] as Deserialize>::N];
                for i in 0..<[Field; O] as Deserialize>::N {
                    member_fields[i] = serialized[i + offset];
                }
                let fields = Deserialize::deserialize(member_fields);
                offset += <[Field; O] as Deserialize>::N;

                Self { fields }
            }
        }
    }
}

impl Deserialize for Field {
    let N: u32 = 1;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        fields[0]
    }
}

impl<T, let M: u32> Deserialize for [T; M]
where
    T: Deserialize,
{
    let N: u32 = <T as Deserialize>::N * M;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        let mut result: [T; M] = std::mem::zeroed();

        for i in 0..M {
            let mut element_fields = [0; <T as Deserialize>::N];
            for j in 0..<T as Deserialize>::N {
                element_fields[j] = fields[i * <T as Deserialize>::N + j];
            }
            result[i] = T::deserialize(element_fields);
        }

        result
    }
}

// impl<let M: u32> Deserialize for [Field; M] {
//     let N: u32 = <Field as Deserialize>::N * M;

//     fn deserialize(fields: [Field; Self::N]) -> Self {
//         let mut result: [Field; M] = std::mem::zeroed();
//         for i in 0..M {
//             let mut element_fields = [0; <Field as Deserialize>::N];
//             for j in 0..<Field as Deserialize>::N {
//                 element_fields[j] = fields[i * <Field as Deserialize>::N + j];
//             }
//             result[i] = Field::deserialize(element_fields);
//         }
//         result
//     }
// }

#[derive(Deserialize)]
pub struct Log<let O: u32> {
    pub fields: [Field; O],
}

fn main(serialized: [Field; 10]) -> pub Field {
    // let log = Log::<10>::deserialize(serialized);
    // log.fields[0] // Return first field of deserialized log
    0
}
