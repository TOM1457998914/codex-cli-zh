use serde::Serialize;
use std::{env, fs};
use syn::{
    visit::{self, Visit},
    *,
};
#[derive(Serialize)]
struct Value {
    function: String,
    kind: String,
    text: String,
    line: usize,
    column: usize,
}
struct Collector {
    function: String,
    kind: Option<String>,
    values: Vec<Value>,
}
fn tests(attrs: &[Attribute]) -> bool {
    attrs.iter().any(|a|a.path().is_ident("test") || a.path().segments.last().is_some_and(|s|s.ident=="test") || matches!(&a.meta,Meta::List(m) if m.path.is_ident("cfg")&&m.tokens.to_string()=="test"))
}
impl<'a> Visit<'a> for Collector {
    fn visit_item_mod(&mut self, n: &'a ItemMod) {
        if !tests(&n.attrs) {
            visit::visit_item_mod(self, n)
        }
    }
    fn visit_item_impl(&mut self, n: &'a ItemImpl) {
        if !tests(&n.attrs) {
            visit::visit_item_impl(self, n)
        }
    }
    fn visit_item_struct(&mut self, n: &'a ItemStruct) {
        if !tests(&n.attrs) {
            visit::visit_item_struct(self, n)
        }
    }
    fn visit_item_enum(&mut self, n: &'a ItemEnum) {
        if !tests(&n.attrs) {
            visit::visit_item_enum(self, n)
        }
    }
    fn visit_item_fn(&mut self, n: &'a ItemFn) {
        if tests(&n.attrs) {
            return;
        }
        let old = std::mem::replace(&mut self.function, n.sig.ident.to_string());
        visit::visit_item_fn(self, n);
        self.function = old;
    }
    fn visit_impl_item_fn(&mut self, n: &'a ImplItemFn) {
        if tests(&n.attrs) {
            return;
        }
        let old = std::mem::replace(&mut self.function, n.sig.ident.to_string());
        visit::visit_impl_item_fn(self, n);
        self.function = old;
    }
    fn visit_attribute(&mut self, n: &'a Attribute) {
        if ["serde", "strum", "arg", "clap", "command"]
            .iter()
            .any(|name| n.path().is_ident(name))
        {
            // Attribute serialization and argument IDs are checked through their literal tokens.
            fn tokens(c: &mut Collector, s: proc_macro2::TokenStream) {
                for t in s {
                    match t {
                        proc_macro2::TokenTree::Group(g) => tokens(c, g.stream()),
                        proc_macro2::TokenTree::Literal(l) => {
                            if let Ok(v) = syn::parse_str::<LitStr>(&l.to_string()) {
                                let p = l.span().start();
                                c.values.push(Value {
                                    function: c.function.clone(),
                                    kind: "attribute".into(),
                                    text: v.value(),
                                    line: p.line,
                                    column: p.column,
                                });
                            }
                        }
                        _ => {}
                    }
                }
            }
            if let Meta::List(m) = &n.meta {
                tokens(self, m.tokens.clone())
            }
        }
    }
    fn visit_pat(&mut self, n: &'a Pat) {
        let old = self.kind.replace("pattern".into());
        visit::visit_pat(self, n);
        self.kind = old;
    }
    fn visit_local(&mut self, n: &'a Local) {
        let pattern = match &n.pat {
            Pat::Type(typed) => typed.pat.as_ref(),
            other => other,
        };
        let old = self.kind.clone();
        if let Pat::Ident(binding) = pattern {
            let name = binding.ident.to_string();
            if [
                "id",
                "key",
                "config_key",
                "action",
                "action_id",
                "model",
                "mode",
            ]
            .contains(&name.as_str())
            {
                self.kind = Some(format!("local:{name}"));
            }
        }
        visit::visit_local(self, n);
        self.kind = old;
    }
    fn visit_expr_tuple(&mut self, n: &'a ExprTuple) {
        let keymap_context = matches!(n.elems.first(), Some(Expr::Path(path))
            if path.path.segments.iter().any(|segment| segment.ident == "KeymapContext"));
        if keymap_context {
            for (index, value) in n.elems.iter().enumerate() {
                let old = self.kind.clone();
                if index == 1 {
                    self.kind = Some("keymap-action".into());
                }
                visit::visit_expr(self, value);
                self.kind = old;
            }
        } else {
            visit::visit_expr_tuple(self, n);
        }
    }
    fn visit_expr_method_call(&mut self, n: &'a ExprMethodCall) {
        let old = self.kind.clone();
        if [
            "starts_with",
            "ends_with",
            "strip_prefix",
            "strip_suffix",
            "split_once",
            "split",
            "splitn",
            "contains",
            "contains_key",
            "eq_ignore_ascii_case",
            "get",
            "get_mut",
            "remove",
            "insert",
            "replace",
            "replacen",
            "trim_start_matches",
            "trim_end_matches",
            "primary_hint",
        ]
        .iter()
        .any(|name| n.method == *name)
        {
            self.kind = Some(format!("method:{}", n.method));
        }
        visit::visit_expr_method_call(self, n);
        self.kind = old;
    }
    fn visit_expr_binary(&mut self, n: &'a ExprBinary) {
        let old = self.kind.clone();
        if matches!(n.op, BinOp::Eq(_) | BinOp::Ne(_)) {
            self.kind = Some("comparison".into());
        }
        visit::visit_expr_binary(self, n);
        self.kind = old;
    }
    fn visit_field_value(&mut self, n: &'a FieldValue) {
        let old = self.kind.clone();
        if let Member::Named(name) = &n.member {
            if [
                "id",
                "key",
                "config_key",
                "view_id",
                "command",
                "method",
                "model",
                "model_provider",
                "value",
            ]
            .iter()
            .any(|field| name == *field)
            {
                self.kind = Some(format!("field:{name}"));
            }
        }
        visit::visit_field_value(self, n);
        self.kind = old;
    }
    fn visit_macro(&mut self, n: &'a Macro) {
        let Some(name) = n.path.segments.last().map(|s| s.ident.to_string()) else {
            return;
        };
        if name == "matches" {
            use syn::parse::Parser;
            let parser =
                |input: syn::parse::ParseStream| -> syn::Result<(Expr, Pat, Option<Expr>)> {
                    let value = input.parse()?;
                    let _: Token![,] = input.parse()?;
                    let pattern = Pat::parse_multi_with_leading_vert(input)?;
                    let guard = if input.peek(Token![if]) {
                        let _: Token![if] = input.parse()?;
                        Some(input.parse()?)
                    } else {
                        None
                    };
                    if input.peek(Token![,]) {
                        let _: Token![,] = input.parse()?;
                    }
                    Ok((value, pattern, guard))
                };
            let (value, pattern, guard) = parser.parse2(n.tokens.clone()).unwrap_or_else(|error| {
                panic!("Could not inspect matches! in {}: {error}", self.function)
            });
            visit::visit_expr(self, &value);
            let old = self.kind.replace("pattern".into());
            visit::visit_pat(self, &pattern);
            self.kind = old;
            if let Some(guard) = guard {
                visit::visit_expr(self, &guard);
            }
            return;
        }
        if [
            "format",
            "format_args",
            "write",
            "writeln",
            "println",
            "eprintln",
        ]
        .contains(&name.as_str())
        {
            use syn::parse::Parser;
            if let Ok(args) = syn::punctuated::Punctuated::<Expr, Token![,]>::parse_terminated
                .parse2(n.tokens.clone())
            {
                for expr in args {
                    visit::visit_expr(self, &expr);
                }
            }
            return;
        }
        if name != "json" {
            return;
        }
        fn collect(c: &mut Collector, stream: proc_macro2::TokenStream) {
            for token in stream {
                match token {
                    proc_macro2::TokenTree::Group(g) => collect(c, g.stream()),
                    proc_macro2::TokenTree::Literal(l) => {
                        if let Ok(s) = syn::parse_str::<LitStr>(&l.to_string()) {
                            let p = l.span().start();
                            c.values.push(Value {
                                function: c.function.clone(),
                                kind: "json-macro".into(),
                                text: s.value(),
                                line: p.line,
                                column: p.column,
                            });
                        }
                    }
                    _ => {}
                }
            }
        }
        collect(self, n.tokens.clone());
    }
    fn visit_lit_str(&mut self, n: &'a LitStr) {
        if let Some(kind) = &self.kind {
            let p = n.span().start();
            self.values.push(Value {
                function: self.function.clone(),
                kind: kind.clone(),
                text: n.value(),
                line: p.line,
                column: p.column,
            });
        }
    }
}
fn main() {
    let args: Vec<_> = env::args().collect();
    let source = fs::read_to_string(&args[1]).unwrap();
    let ast = syn::parse_file(&source).unwrap();
    let mut c = Collector {
        function: String::new(),
        kind: None,
        values: Vec::new(),
    };
    c.visit_file(&ast);
    println!("{}", serde_json::to_string(&c.values).unwrap());
}

#[cfg(test)]
mod contract_tests {
    use super::*;
    fn collect(source: &str) -> Vec<Value> {
        let ast = syn::parse_file(source).unwrap();
        let mut c = Collector {
            function: String::new(),
            kind: None,
            values: Vec::new(),
        };
        c.visit_file(&ast);
        c.values
    }
    #[test]
    fn matches_macro_preserves_alias_patterns_and_guard_keys() {
        let values = collect(
            r#"fn dispatch(value: &str) {
            let label = "Human label";
            let _ = matches!(value, | "disable" | "hide" | "off" | "none",);
            let _ = matches!(value, "active" if map.contains_key("wire_key"));
        }"#,
        );
        for expected in ["disable", "hide", "off", "none", "active", "wire_key"] {
            assert!(
                values.iter().any(|value| value.text == expected),
                "{expected}"
            );
        }
        assert!(!values.iter().any(|value| value.text == "Human label"));
    }
    #[test]
    #[should_panic(expected = "Could not inspect matches!")]
    fn unsupported_matches_syntax_cannot_silently_bypass_the_audit() {
        collect(r#"fn parse(value: &str) { let _ = matches!(value,); }"#);
    }
    #[test]
    fn checks_indirect_keymap_actions_and_named_identifiers() {
        let values = collect(
            r#"fn hint() {
            let (context, action) = (KeymapContext::Composer, "submit");
            let key: &str = "wire_key";
            let action = if enabled { "enable" } else { "disable" };
            let label = "Human label";
        }"#,
        );
        for expected in ["submit", "wire_key", "enable", "disable"] {
            assert!(
                values.iter().any(|value| value.text == expected),
                "{expected}"
            );
        }
        assert!(!values.iter().any(|value| value.text == "Human label"));
    }
    #[test]
    fn checks_parser_aliases_and_wire_keys_without_treating_plain_labels_as_contracts() {
        let values = collect(
            r#"#[serde(rename="wire_type")] struct Value { value:String }
    fn parse(value:&str){let title="Human title";if value=="yes"{}match value{"day"=>{},_=>{}}let _=map.get("endpoint");let _=format!("Display {}",map.get("nested_key"));let _=serde_json::json!({"method":"thread/list"});}"#,
        );
        for expected in [
            "wire_type",
            "yes",
            "day",
            "endpoint",
            "nested_key",
            "method",
            "thread/list",
        ] {
            assert!(
                values.iter().any(|v| v.text == expected),
                "missing {expected}"
            );
        }
        assert!(!values.iter().any(|v| v.text == "Human title"));
    }
    #[test]
    fn ignores_test_only_code_but_continues_scanning_production_code() {
        let values = collect(
            r#"#[cfg(test)] mod tests {fn fixture(){match value{"fixture_key"=>{},_=>{}}}}
    fn real(){match value{"live_key"=>{},_=>{}}}"#,
        );
        assert_eq!(
            values.iter().map(|v| v.text.as_str()).collect::<Vec<_>>(),
            vec!["live_key"]
        );
    }
}
