#[derive_via(derive_serialize)]
pub trait Serialize {
    let N: u32;

    fn serialize(self) -> [Field; N];
}

pub comptime fn derive_serialize(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();
    let nested_struct = typ.as_data_type().unwrap();
    let params = nested_struct.0.fields(nested_struct.1);

    let generics = s.generics();

    // We check that each generic's second tuple field (maybe_numeric_generic) is Some,
    // which indicates it's a numeric generic parameter (like N in Foo<N>).
    // Non-numeric generics (like T in Foo<T>) would have None in this field.
    // derive_serialize requires all generics to be numeric.
    generics.for_each(|(_, maybe_numeric_generic)| {
        assert(
            maybe_numeric_generic.is_some(),
            "All generic parameters must be numeric when deriving Serialize",
        );
    });

    // Constructs the "<let N: u32, let M: u8>" string that is injected after the "impl" keyword in e.g.
    // "impl<let N: u32, let M: u8> Serialize for Foo<N, M>".
    // Returns an empty quote if the struct has no generics.
    let generics_declarations = if generics.len() > 0 {
        let generics_declarations_items = generics
            .map(|(name, typ)| {
                let integer_type = typ.unwrap();
                quote {let $name: $integer_type}
            })
            .join(quote {,});
        quote {<$generics_declarations_items>}
    } else {
        // The struct doesn't have any generics defined, so we just return an empty quote.
        quote {}
    };

    std::println(generics_declarations);

    // The following will give us <type_of_struct_member_1 as Serialize>::N + <type_of_struct_member_2 as Serialize>::N + ...
    let right_hand_side_of_definition_of_n = params
        .map(|(_, param_type, _): (Quoted, Type, Quoted)| {
            quote {
            <$param_type as $crate::Serialize>::N
        }
        })
        .join(quote {+});

    // Generates serialization code for each struct member that:
    // 1. Serializes the member
    // 2. Copies serialized fields into result array at correct offset
    // 3. Updates offset for next member
    let serialization_of_struct_members = params
        .map(|(param_name, param_type, _): (Quoted, Type, Quoted)| {
            quote {
                let serialized_member = $crate::Serialize::serialize(self.$param_name);
                let serialized_member_len = <$param_type as $crate::Serialize>::N;
                for i in 0..serialized_member_len {
                    result[i + offset] = serialized_member[i];
                }
                offset += serialized_member_len;
            }
        })
        .join(quote {});

    quote {
        impl $generics_declarations $crate::Serialize for $typ {
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

// // Note: We currently don't support derivation of Serialize and Deserialize traits for types with generics so we have
// // the manual implementation below.
// impl<let M: u32> Serialize for Log<M> {
//     let N: u32 = M + 1; // +1 for length field

//     #[inline_always]
//     fn serialize(self) -> [Field; Self::N] {
//         let mut result = [0; Self::N];

//         // Copy log fields
//         for i in 0..M {
//             result[i] = self.fields[i];
//         }

//         // Store length as last field
//         result[M] = self.length as Field;

//         result
//     }
// }

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

impl<T, let M: u32> Serialize for [T; M]
where
    T: Serialize,
{
    let N: u32 = <T as Serialize>::N * M;

    fn serialize(self) -> [Field; Self::N] {
        let mut result: [Field; _] = std::mem::zeroed();
        for i in 0..M {
            let serialized_t = self[i].serialize();
            for j in 0..<T as Serialize>::N {
                result[i * <T as Serialize>::N + j] = serialized_t[j];
            }
        }
        result
    }
}

#[derive(Serialize)]
pub struct Log<let N: u32, let M: u32> {
    pub fields: [Field; N],
    pub what: [Field; M],
    // The actual length (number of fields) of the log to be included in the blobs.
    pub length: u32,
}

fn main() -> pub Field {
    let log = Log {
        fields: [0 as Field; 10], // Creating a log with 10 fields initialized to 0
        what: [0 as Field; 10],
        length: 10,
    };

    let serialized = log.serialize();
    serialized[0] // Return first field of serialized log
}
