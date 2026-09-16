; Mirrors tree-sitter-gossamer/queries/highlights.scm but tuned
; for Zed's highlight name conventions.

(line_comment) @comment
(block_comment) @comment

(integer_literal) @number
(float_literal) @number
(boolean_literal) @boolean
(string_literal) @string
(multiline_string_literal) @string
(raw_string_literal) @string
(raw_byte_string_literal) @string
(byte_string_literal) @string
(byte_literal) @string.special
(char_literal) @string.special
(label) @label

((identifier) @constant
  (#match? @constant "^(Some|None|Ok|Err)$"))
((type_identifier) @constant
  (#match? @constant "^(Some|None|Ok|Err)$"))

(primitive_type) @type
(type_identifier) @type

(identifier) @variable

(field_declaration name: (identifier) @property)
(parameter pattern: (identifier) @variable.parameter)
(closure_parameter pattern: (identifier) @variable.parameter)

(function_item name: (identifier) @function)
(call_expression function: (identifier) @function)
(generic_function function: (identifier) @function)
(method_call_expression (identifier) @function.method)
(macro_invocation macro: (identifier) @function.special)

[
  "+" "-" "*" "/" "%" "+%" "-%" "*%"
  "|" "^" "!"
  "<" ">" "=" "==" "!=" "<=" ">="
  "&&" "||"
  "<<" ">>"
  "->" "=>"
  "+=" "-=" "*=" "/=" "%=" "&=" "|=" "^=" "<<=" ">>=" "+%=" "-%=" "*%="
  ".." "..="
  "::" "::<"
  "@" "?" "|>"
] @operator

[ "#[" "#{" ] @punctuation.bracket

(reference_type "&" @keyword)
(reference_pattern "&" @keyword)
(reference_expression "&" @keyword)
(binary_expression "&" @operator)

(spread_argument) @operator

; Only tokens the grammar actually defines may appear here; an unknown
; token makes the whole query fail to load.
[
  "as" "async" "await" "comptime" "const" "crate" "enum"
  "extern" "fn" "impl" "let" "mod" "mut" "newtype" "package" "packed" "pub" "self"
  "Self" "static" "struct" "super" "trait" "type" "unsafe" "use"
  "where" "yield"
  "if" "else" "match" "loop" "while" "for" "in" "break"
  "continue" "return" "defer" "select" "default" "arena" "cohort"
] @keyword

(reserved_keyword) @keyword
(continue_expression) @keyword

(attribute_item) @attribute
(attribute (identifier) @attribute)

(named_argument name: (identifier) @variable.parameter)
(cohort_header name: (identifier) @variable.parameter)
(map_entry key: (identifier) @property)
(associated_type_binding name: (type_identifier) @type)
