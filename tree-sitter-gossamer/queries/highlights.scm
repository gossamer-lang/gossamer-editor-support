; Helix tree-sitter highlight queries: later patterns override earlier ones.
; Catch-alls go first; more specific overrides come last.

; Comments
(line_comment) @comment
(block_comment) @comment

; Literals
(integer_literal) @number
(float_literal) @number
(boolean_literal) @constant.builtin.boolean
(string_literal) @string
(multiline_string_literal) @string
(raw_string_literal) @string
(raw_byte_string_literal) @string
(byte_string_literal) @string
(byte_literal) @string.special
(char_literal) @string
(label) @label

; Catch-all identifiers (specific cases override these below)
(identifier) @variable
(type_identifier) @type
(primitive_type) @type.builtin

; Built-in generic/container types
((type_identifier) @type.builtin
  (#match? @type.builtin "^(Arc|BTreeMap|BTreeSet|Box|Deque|DynValue|Fn|I64Vec|Iterator|Map|MaxHeap|MinHeap|Mutex|Never|Option|Queue|Range|Rc|Receiver|Result|RwLock|Sender|Set|Stack|String|U8Vec|Unit|Vec|Weak)$"))

; Built-in constructors (Some/None/Ok/Err live as paths, match by name)
((identifier) @constant.builtin
  (#match? @constant.builtin "^(Some|None|Ok|Err)$"))
((type_identifier) @constant.builtin
  (#match? @constant.builtin "^(Some|None|Ok|Err)$"))

; Functions
(function_item name: (identifier) @function)
(call_expression function: (identifier) @function)
(generic_function function: (identifier) @function)
(method_call_expression (identifier) @function.method)

; Prelude functions no module exports, and the compiler-known calls
((identifier) @function.builtin
  (#match? @function.builtin "^(assert|assert_eq|spawn|channel|println|print|eprintln|eprint|format|panic|matches|todo|unimplemented|unreachable|dbg|codegen)$"))

; Built-in macros (`println!`, `matches!`, `regex!`, ...)
(macro_invocation macro: (identifier) @function.macro)
(spread_argument) @operator

; Fields
(field_expression (identifier) @variable.field .)
(field_declaration name: (identifier) @variable.field)

; Parameters
(parameter pattern: (identifier) @variable.parameter)
(closure_parameter pattern: (identifier) @variable.parameter)

; Operators
[
  "+"
  "-"
  "*"
  "+%"
  "-%"
  "*%"
  "/"
  "%"
  "&"
  "|"
  "^"
  "!"
  "<"
  ">"
  "="
  "=="
  "!="
  "<="
  ">="
  "&&"
  "||"
  "<<"
  ">>"
  "->"
  "=>"
  "+="
  "-="
  "*="
  "/="
  "%="
  "&="
  "|="
  "^="
  "<<="
  ">>="
  "+%="
  "-%="
  "*%="
  ".."
  "..="
  "::"
  "::<"
  "@"
  "?"
] @operator

"|>" @operator.special

; Punctuation
[ "(" ")" "[" "]" "{" "}" "#[" "#{" ] @punctuation.bracket
[ "," ";" ":" "." ] @punctuation.delimiter

; Keywords
[
  "as"
  "async"
  "await"
  "comptime"
  "const"
  "crate"
  "enum"
  "extern"
  "fn"
  "impl"
  "let"
  "mod"
  "mut"
  "newtype"
  "package"
  "packed"
  "pub"
  "self"
  "Self"
  "static"
  "struct"
  "super"
  "trait"
  "type"
  "unsafe"
  "use"
  "where"
  "yield"
] @keyword

[
  "if"
  "else"
  "match"
  "loop"
  "while"
  "for"
  "in"
  "break"
  "return"
  "defer"
  "select"
  "default"
  "arena"
  "cohort"
  "continue"
] @keyword.control

(reserved_keyword) @keyword
(continue_expression) @keyword.control

; Attributes
(attribute_item) @attribute
(attribute (identifier) @attribute)

; Named and defaulted arguments
(named_argument name: (identifier) @variable.parameter)
(cohort_header name: (identifier) @variable.parameter)

; A bare map key reads as a key, not a variable
(map_entry key: (identifier) @variable.field)

; Associated-type equality constraint: `T: Iterator<Item = i64>`
(associated_type_binding name: (type_identifier) @type)
