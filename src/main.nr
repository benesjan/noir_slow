#[derive_via(derive_deserialize)]
pub trait Deserialize {
    let N: u32;

    fn deserialize(fields: [Field; N]) -> Self;
}

comptime fn get_generics_declarations(s: TypeDefinition) -> Quoted {
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
    if generics.len() > 0 {
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
    }
}

pub(crate) comptime fn derive_deserialize(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();
    let nested_struct = typ.as_data_type().unwrap();
    let params = nested_struct.0.fields(nested_struct.1);

    let generics_declarations = get_generics_declarations(s);

    // The following will give us <type_of_struct_member_1 as Deserialize>::N + <type_of_struct_member_2 as Deserialize>::N + ...
    let right_hand_side_of_definition_of_n = params
        .map(|(_, param_type, _): (Quoted, Type, Quoted)| {
            quote {
            <$param_type as Deserialize>::N
        }
        })
        .join(quote {+});

    // This generates deserialization code for each struct member that and concatenates them together.
    let deserialization_of_struct_members = params
        .map(|(param_name, param_type, _): (Quoted, Type, Quoted)| {
            std::println(param_type);
            quote {
                let mut member_fields = [0; <$param_type as Deserialize>::N];
                for i in 0..<$param_type as Deserialize>::N {
                    member_fields[i] = serialized[i + offset];
                }
                let $param_name = <$param_type as Deserialize>::deserialize(member_fields);
                offset += <$param_type as Deserialize>::N;
            }
        })
        .join(quote {});

    // We join the struct member names with a comma to be used in the `Self { ... }` syntax
    // This will give us e.g. `a, b, c` for a struct with three fields named `a`, `b`, and `c`.
    let struct_members = params
        .map(|(param_name, _, _): (Quoted, Type, Quoted)| quote { $param_name })
        .join(quote {,});

    quote {
        impl $generics_declarations Deserialize for $typ {
            let N: u32 = $right_hand_side_of_definition_of_n;

            #[inline_always]
            fn deserialize(serialized: [Field; Self::N]) -> Self {
                let mut offset = 0;

                $deserialization_of_struct_members

                Self { $struct_members }
            }
        }
    }
}

impl<T, let M: u32> Deserialize for [T; M]
where
    T: Deserialize,
{
    let N: u32 = <T as Deserialize>::N * M;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        let mut result: [T; M] = std::mem::zeroed();
        let mut offset = 0;

        for i in 0..M {
            let mut element_fields = [0; <T as Deserialize>::N];
            for j in 0..<T as Deserialize>::N {
                element_fields[j] = fields[offset + j];
            }
            result[i] = T::deserialize(element_fields);
            offset += <T as Deserialize>::N;
        }

        result
    }
}

impl Deserialize for Field {
    let N: u32 = 1;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        fields[0]
    }
}

impl Deserialize for u32 {
    let N: u32 = 1;

    fn deserialize(fields: [Field; Self::N]) -> Self {
        fields[0] as u32
    }
}

#[derive(Deserialize)]
pub struct Log<let O: u32> {
    pub fields: [Field; O],
    // pub length: u32,
}

fn main() -> pub Field {
    let serialized = [0 as Field; 10]; // Array of 11 fields (10 for fields + 1 for length)

    let log = Log::<10>::deserialize(serialized);
    log.fields[0] // Return first field of deserialized log
}
