/**
 * tree-sitter-gossamer
 *
 * Grammar for the Gossamer programming language. Surface syntax is
 * Rust-flavoured with managed references, goroutines, comptime, and
 * optional semicolons at statement boundaries.
 */

const PREC = {
  postfix: 13,
  unary: 12,
  cast: 11,
  multiplicative: 10,
  additive: 9,
  shift: 8,
  bitand: 7,
  bitxor: 6,
  bitor: 5,
  comparative: 4,
  and: 3,
  or: 2,
  range: 1,
  pipe: 0,
  list: -1,
  assign: -2,
  closure: -3,
};

const integer_types = [
  "i8", "i16", "i32", "i64", "i128", "isize",
  "u8", "u16", "u32", "u64", "u128", "usize",
];

const float_types = ["f32", "f64"];

const contextual_words = [
  "arena", "cohort", "comptime", "default", "defer", "newtype", "packed", "select",
];

const primitive_types = integer_types
  .concat(float_types)
  .concat(["bool", "char", "str"]);

module.exports = grammar({
  name: "gossamer",

  extras: $ => [
    /\s+/,
    $.line_comment,
    $.block_comment,
  ],

  // Block comments nest (`/* a /* b */ c */` is one comment), a
  // triple-quoted body runs across lines to the first `"""` an escape has
  // not consumed, and a raw string closes only at a quote followed by as many
  // `#` as opened it. None is expressible as a single regex token, so
  // src/scanner.c lexes them.
  externals: $ => [
    $.block_comment,
    $.multiline_string_literal,
    $._line_separator,
    $.raw_string_literal,
    $.raw_byte_string_literal,
  ],

  word: $ => $.identifier,

  conflicts: $ => [
    [$._expression, $.struct_expression],
    [$._pattern, $.struct_pattern],
    [$._pattern, $.tuple_struct_pattern],
    [$._pattern, $._expression],
    [$.tuple_expression, $.tuple_pattern],
    [$.struct_expression, $.struct_pattern],
    [$.slice_pattern, $.array_expression],
    [$._path_segment, $.struct_pattern],
    [$._path_segment, $._type],
    [$.type_item, $.associated_type_item],
    [$.const_item, $.associated_const_item],
    [$.tuple_field_declaration, $.tuple_type],
    [$._expression, $._index_receiver],
    [$.attribute, $.call_expression],
    [$._visibility],
  ],

  rules: {
    // Entry files may contain bare statements alongside items.
    source_file: $ => repeat($._statement),

    // An outer attribute belongs to the item after it, which is what keeps a
    // `#[f(x)]` Vec literal at the end of a block from reading as one.
    _item: $ => choice(
      $._bare_item,
      seq(repeat1($.attribute_item), $._bare_item),
      alias($._inner_attribute_item, $.attribute_item),
    ),

    _bare_item: $ => choice(
      $.use_declaration,
      $.const_item,
      $.static_item,
      $.struct_item,
      $.enum_item,
      $.trait_item,
      $.impl_item,
      $.function_item,
      $.mod_item,
      $.type_item,
      $.extern_item,
    ),

    line_comment: _ => token(seq("//", /[^\n]*/)),

    // An attribute names a path, optionally with arguments. `#[f(x)]` is
    // also a one-element Vec literal, so both readings stay open until the
    // input settles it, and the attribute wins a tie.
    attribute_item: $ => seq("#[", $.attribute, "]"),

    _inner_attribute_item: $ => seq("#![", $.attribute, "]"),

    attribute: $ => prec(PREC.postfix, prec.dynamic(1, seq(
      $._path,
      optional(choice(
        seq("(", commaSep($, choice($.named_argument, $._expression)), ")"),
        seq("=", $._expression),
      )),
    ))),

    // `pub(package)` is the one restricted form the language has.
    _visibility: $ => seq("pub", optional(seq("(", "package", ")"))),

    use_declaration: $ => prec.right(seq(
      optional($._visibility),
      "use",
      $._use_path,
      optional(";"),
    )),

    // A string names a project dependency: `use "example.com/intcode" as ic`.
    _use_path: $ => seq(
      choice($._path_segment, $.string_literal),
      optional(choice(
        seq("::", "*"),
        seq("::", "{", commaSep($, $._use_path), "}"),
        seq("::", $._use_path),
        seq("as", $.identifier),
      )),
    ),

    _path: $ => seq(
      $._path_segment_with_generics,
      repeat(seq("::", $._path_segment_with_generics)),
    ),

    _path_segment: $ => choice(
      $._name,
      $.type_identifier,
      "self",
      "Self",
      "super",
      "crate",
    ),

    _path_segment_with_generics: $ => prec.right(seq(
      $._path_segment,
      optional(seq("::<", commaSep1($, $._generic_arg), ">")),
    )),

    mod_item: $ => seq(
      optional($._visibility),
      "mod",
      field("name", $.identifier),
      choice(";", $.declaration_block),
    ),

    // `newtype` is the opaque form: a distinct type over the same representation.
    type_item: $ => prec.right(seq(
      optional($._visibility),
      choice("type", "newtype"),
      field("name", choice($.type_identifier, $.identifier)),
      optional($.type_parameters),
      "=",
      $._type,
      optional(";"),
    )),

    extern_item: $ => seq(
      optional("unsafe"),
      "extern",
      optional($.string_literal),
      choice(";", $.block),
    ),

    const_item: $ => prec.right(seq(
      optional($._visibility),
      "const",
      field("name", $.identifier),
      ":",
      field("type", $._type),
      "=",
      field("value", $._expression),
      optional(";"),
    )),

    static_item: $ => prec.right(seq(
      optional($._visibility),
      "static",
      optional("mut"),
      field("name", $.identifier),
      ":",
      field("type", $._type),
      "=",
      field("value", $._expression),
      optional(";"),
    )),

    struct_item: $ => prec.right(seq(
      optional($._visibility),
      "struct",
      field("name", $.type_identifier),
      optional($.type_parameters),
      optional(seq("where", commaSep1($, $.where_clause))),
      choice(
        seq("{", commaSep($, $.field_declaration), "}"),
        seq("(", commaSep($, $.tuple_field_declaration), ")", optional(";")),
        ";",
        blank(),
      ),
      optional(seq("where", commaSep1($, $.where_clause))),
    )),

    // `packed` stores the discriminant in the fewest bits, and `: uN` names
    // its width; `u1`..`u64` are all accepted, so the width is a plain name.
    enum_item: $ => seq(
      optional($._visibility),
      optional("packed"),
      "enum",
      field("name", $.type_identifier),
      optional($.type_parameters),
      optional(seq(":", field("representation", choice($.primitive_type, $.identifier)))),
      optional(seq("where", commaSep1($, $.where_clause))),
      "{",
      commaSep($, $.enum_variant),
      "}",
    ),

    enum_variant: $ => seq(
      repeat($.attribute_item),
      field("name", $.type_identifier),
      optional(choice(
        seq("(", commaSep($, $.tuple_field_declaration), ")"),
        seq("{", commaSep($, $.field_declaration), "}"),
      )),
      optional(seq("=", $._expression)),
    ),

    field_declaration: $ => seq(
      repeat($.attribute_item),
      optional($._visibility),
      field("name", $._name),
      ":",
      field("type", $._type),
    ),

    tuple_field_declaration: $ => seq(
      repeat($.attribute_item),
      optional($._visibility),
      field("type", $._type),
    ),

    trait_item: $ => seq(
      optional($._visibility),
      "trait",
      field("name", $.type_identifier),
      optional($.type_parameters),
      optional(seq(":", $._type, repeat(seq("+", $._type)))),
      optional(seq("where", commaSep1($, $.where_clause))),
      $.declaration_block,
    ),

    impl_item: $ => seq(
      "impl",
      optional($.type_parameters),
      field("type", $._type),
      optional(seq("for", field("for_type", $._type))),
      optional(seq("where", commaSep1($, $.where_clause))),
      $.declaration_block,
    ),

    declaration_block: $ => seq(
      "{",
      repeat(choice($._item, $.associated_type_item, $.associated_const_item)),
      "}",
    ),

    associated_type_item: $ => seq(
      repeat($.attribute_item),
      optional($._visibility),
      "type",
      field("name", choice($.type_identifier, $.identifier)),
      optional(seq(":", $._type, repeat(seq("+", $._type)))),
      optional(seq("=", $._type)),
      optional(";"),
    ),

    associated_const_item: $ => seq(
      repeat($.attribute_item),
      optional($._visibility),
      "const",
      field("name", $.identifier),
      ":",
      field("type", $._type),
      optional(seq("=", field("value", $._expression))),
      optional(";"),
    ),

    function_item: $ => prec.right(seq(
      optional($._visibility),
      optional("comptime"),
      optional("unsafe"),
      "fn",
      field("name", $._name),
      optional($.type_parameters),
      field("parameters", $.parameters),
      optional(seq("->", field("return_type", $._type))),
      optional(seq("where", commaSep1($, $.where_clause))),
      optional(choice($.block, ";")),
    )),

    where_clause: $ => seq(
      $._type,
      ":",
      $._type,
      repeat(seq("+", $._type)),
    ),

    type_parameters: $ => seq(
      "<",
      commaSep1($, choice(
        seq("const", $.identifier, ":", $._type, optional(seq("=", $.literal))),
        seq($.identifier, ":", $._type, repeat(seq("+", $._type))),
        seq($.identifier, "=", $._type),
        $.label,
        $.identifier,
      )),
      ">",
    ),

    parameters: $ => seq(
      "(",
      commaSep($, choice(
        seq(optional("&"), optional("mut"), "self"),
        $.parameter,
      )),
      ")",
    ),

    parameter: $ => seq(
      optional("comptime"),
      field("pattern", $._pattern),
      ":",
      field("type", $._type),
      optional(seq("=", field("default", $._expression))),
    ),

    block: $ => seq(
      "{",
      repeat($._statement),
      optional($._expression),
      "}",
    ),

    _statement: $ => choice(
      $.let_declaration,
      $.arena_block,
      $._item,
      prec.right(seq($._expression, optional(";"))),
      prec.right(seq($.destructuring_assignment, optional(";"))),
      ";",
    ),

    // `arena` is contextual: statement-position `arena { ... }` frees
    // allocations made inside the block when it exits.
    arena_block: $ => seq("arena", $.block),

    // `cohort` is contextual too: the block owns every goroutine spawned
    // inside it and joins them on each exit path. The optional header
    // carries settings (`cohort(timeout: 500) { .. }`).
    cohort_block: $ => seq(
      "cohort",
      optional($.cohort_header),
      $.block,
    ),

    cohort_header: $ => seq(
      "(",
      commaSep($, seq(field("name", $.identifier), ":", field("value", $._expression))),
      ")",
    ),

    // `let a, b = pair` and `let x, y = 7, 8` bind a plain list; only a
    // comma separates its elements.
    let_declaration: $ => prec.right(seq(
      "let",
      field("pattern", choice($._pattern, $.pattern_list)),
      optional(seq(":", field("type", $._type))),
      optional(seq("=", field("value", choice($._expression, $.expression_list)))),
      optional(seq("else", field("alternative", $.block))),
      optional(";"),
    )),

    pattern_list: $ => seq(
      choice($._pattern, ".."),
      repeat1(prec(-1, seq(",", choice($._pattern, "..")))),
    ),

    expression_list: $ => seq($._expression, repeat1(prec(PREC.list, seq(",", $._expression)))),

    _pattern: $ => choice(
      $.literal,
      $.tuple_pattern,
      $.slice_pattern,
      $.struct_pattern,
      $.tuple_struct_pattern,
      $.reference_pattern,
      $.range_pattern,
      $.or_pattern,
      $.captured_pattern,
      $.mut_pattern,
      "_",
      $._path,
    ),

    // Prec -1: `&mut x` is a mutable reference pattern, not `&(mut x)`.
    mut_pattern: $ => prec(-1, seq("mut", $._name)),

    tuple_pattern: $ => seq("(", commaSep($, choice($._pattern, "..")), ")"),

    slice_pattern: $ => seq(
      "[",
      commaSep($, choice($._pattern, seq("..", optional($._pattern)))),
      "]",
    ),

    tuple_struct_pattern: $ => seq(
      $._path,
      "(",
      commaSep($, choice($._pattern, "..")),
      ")",
    ),

    struct_pattern: $ => seq(
      $._path,
      "{",
      commaSep($, choice(
        seq($._name, optional(seq(":", $._pattern))),
        "..",
      )),
      "}",
    ),

    reference_pattern: $ => prec(1, seq("&", optional("mut"), $._pattern)),

    range_pattern: $ => prec.right(1, choice(
      seq($.literal, choice("..", "..="), $.literal),
      seq($.literal, ".."),
      seq(choice("..", "..="), optional("-"), $.literal),
    )),

    or_pattern: $ => prec.left(seq($._pattern, "|", $._pattern)),

    captured_pattern: $ => prec(2, seq($._name, "@", $._pattern)),

    _type: $ => choice(
      $.primitive_type,
      $.generic_type,
      $.reference_type,
      $.tuple_type,
      $.array_type,
      $.function_type,
      $._path,
      $.type_identifier,
      "!",
      "_",
    ),

    primitive_type: _ => choice(...primitive_types),

    type_identifier: _ => /[\p{Lu}][\p{XID_Continue}]*/,

    generic_type: $ => prec(1, seq(
      choice($.type_identifier, $._path),
      "<",
      commaSep1($, $._generic_arg),
      ">",
    )),

    reference_type: $ => seq("&", optional("mut"), $._type),

    tuple_type: $ => seq("(", commaSep($, $._type), ")"),

    array_type: $ => seq(
      "[",
      $._type,
      optional(seq(";", $._expression)),
      "]",
    ),

    function_type: $ => prec(1, seq(
      choice("fn", $.type_identifier),
      "(",
      commaSep($, $._type),
      ")",
      optional(seq("->", $._type)),
    )),

    _generic_arg: $ => choice(
      $.associated_type_binding,
      $._type,
      $.integer_literal,
      $.float_literal,
      $.boolean_literal,
    ),

    associated_type_binding: $ => seq(
      field("name", $.type_identifier),
      "=",
      field("type", $._type),
    ),

    _expression: $ => choice(
      $.literal,
      $._path,
      $.unary_expression,
      $.binary_expression,
      $.pipe_expression,
      $.assignment_expression,
      $.call_expression,
      $.generic_function,
      $.macro_invocation,
      $.cast_expression,
      $.try_expression,
      $.field_expression,
      $.method_call_expression,
      $.index_expression,
      $.reference_expression,
      $.range_expression,
      $.tuple_expression,
      $.array_expression,
      $.vec_literal,
      $.set_literal,
      $.map_literal,
      $.struct_expression,
      $.cohort_block,
      $.if_expression,
      $.match_expression,
      $.loop_expression,
      $.while_expression,
      $.for_expression,
      $.return_expression,
      $.break_expression,
      $.continue_expression,
      $.defer_expression,
      $.select_expression,
      $.closure_expression,
      $.unsafe_expression,
      $.comptime_expression,
      $.labelled_loop_expression,
      $.reserved_keyword,
      $.parenthesized_expression,
      $.block,
    ),

    parenthesized_expression: $ => seq("(", $._expression, ")"),

    literal: $ => choice(
      $.integer_literal,
      $.float_literal,
      $.string_literal,
      $.multiline_string_literal,
      $.raw_string_literal,
      $.raw_byte_string_literal,
      $.byte_string_literal,
      $.byte_literal,
      $.char_literal,
      $.boolean_literal,
    ),

    integer_literal: _ => token(seq(
      choice(
        /0x[0-9a-fA-F_]+/,
        /0b[01_]+/,
        /0o[0-7_]+/,
        /[0-9][0-9_]*/,
      ),
      optional(choice(...integer_types)),
    )),

    float_literal: _ => token(seq(
      choice(
        /[0-9][0-9_]*\.[0-9_]+([eE][+-]?[0-9_]+)?/,
        /[0-9][0-9_]*[eE][+-]?[0-9_]+/,
      ),
      optional(choice(...float_types)),
    )),

    string_literal: _ => token(seq(
      '"',
      repeat(choice(/[^"\\]/, /\\([nrt0\\"']|x[0-9a-fA-F]{2}|u\{[0-9a-fA-F]+\})/)),
      '"',
    )),

    byte_string_literal: _ => token(seq(
      'b"',
      repeat(choice(/[^"\\]/, /\\([nrt0\\"']|x[0-9a-fA-F]{2}|u\{[0-9a-fA-F]+\})/)),
      '"',
    )),

    _string_content: _ => /[^"\\]+/,

    escape_sequence: _ => token(seq(
      "\\",
      choice(/[nrt0\\"']/, /x[0-9a-fA-F]{2}/, /u\{[0-9a-fA-F]+\}/),
    )),

    byte_literal: _ => token(seq(
      "b",
      "'",
      choice(/[^'\\]/, seq("\\", choice(/[nrt0\\"']/, /x[0-9a-fA-F]{2}/, /u\{[0-9a-fA-F]+\}/))),
      "'",
    )),

    char_literal: _ => token(seq(
      "'",
      choice(/[^'\\]/, seq("\\", choice(/[nrt0\\"']/, /x[0-9a-fA-F]{2}/, /u\{[0-9a-fA-F]+\}/))),
      "'",
    )),

    boolean_literal: _ => choice("true", "false"),

    label: _ => token(seq("'", /[_\p{XID_Start}][\p{XID_Continue}]*/)),

    reserved_keyword: _ => choice("async", "await", "package", "yield"),

    // Unicode identifiers per UAX #31 (`let cafe = 1` and `let café = 1` parse).
    identifier: _ => /[_\p{XID_Start}][\p{XID_Continue}]*/,

    // The block words open their construct only where one can start and are
    // ordinary names everywhere else: `let select = 1`, `q.defer()`.
    _name: $ => choice($.identifier, $._contextual_word),

    _contextual_word: $ => prec(-1, alias(choice(...contextual_words), $.identifier)),

    unary_expression: $ => prec(PREC.unary, choice(
      seq("-", $._expression),
      seq("!", $._expression),
      seq("*", $._expression),
    )),

    reference_expression: $ => prec(PREC.unary, seq(
      "&",
      optional("mut"),
      $._expression,
    )),

    binary_expression: $ => {
      const table = [
        [PREC.multiplicative, choice("*", "/", "%", "*%")],
        [PREC.additive, choice("+", "-", "+%", "-%")],
        [PREC.shift, choice("<<", ">>")],
        [PREC.bitand, "&"],
        [PREC.bitxor, "^"],
        [PREC.bitor, "|"],
        [PREC.comparative, choice("==", "!=", "<", "<=", ">", ">=")],
        [PREC.and, "&&"],
        [PREC.or, "||"],
      ];

      return choice(...table.map(([prec_, op]) =>
        prec.left(prec_, seq($._expression, op, $._expression)),
      ));
    },

    pipe_expression: $ => prec.left(PREC.pipe, seq($._expression, "|>", $._expression)),

    assignment_expression: $ => prec.right(PREC.assign, seq(
      $._expression,
      $._assignment_operator,
      $._expression,
    )),

    // `a, b = b, a` swaps and `x, y += 2, 3` pairs element-wise; a place
    // list only stands as a whole statement.
    destructuring_assignment: $ => prec.right(PREC.assign, seq(
      field("left", $.expression_list),
      $._assignment_operator,
      field("right", choice($._expression, $.expression_list)),
    )),

    _assignment_operator: _ => choice(
      "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=", "+%=", "-%=", "*%=",
    ),

    range_expression: $ => prec.left(PREC.range, choice(
      seq($._expression, choice("..", "..="), optional($._expression)),
      seq(choice("..", "..="), optional($._expression)),
    )),

    // A label binds with `:`; the `=` spelling still parses, as the compiler
    // rewrites it rather than rejecting the call.
    named_argument: $ => prec(2, seq(
      field("name", $._name),
      choice(":", "="),
      field("value", $._expression),
    )),

    call_expression: $ => prec(PREC.postfix, seq(
      field("function", choice(
        $._path,
        $.field_expression,
        $.method_call_expression,
        $.generic_function,
        $.index_expression,
        $.parenthesized_expression,
      )),
      field("arguments", seq(
        "(",
        commaSep($, choice($.named_argument, $._expression, $.spread_argument)),
        ")",
      )),
    )),

    spread_argument: _ => "...",

    generic_function: $ => prec(1, seq(
      field("function", $._path),
      "::<",
      commaSep1($, $._generic_arg),
      ">",
    )),

    macro_invocation: $ => seq(
      field("macro", $.identifier),
      token.immediate("!"),
      choice(
        seq("(", commaSep($, $._expression), ")"),
        seq("[", choice(
          commaSep($, $._expression),
          seq($._expression, ";", $._expression),
        ), "]"),
      ),
    ),

    cast_expression: $ => prec.left(PREC.cast, seq($._expression, "as", field("type", $._type))),

    try_expression: $ => prec(PREC.postfix, seq($._expression, "?")),

    field_expression: $ => prec(PREC.postfix, seq(
      $._expression,
      ".",
      choice($._name, "await", /[0-9]+/),
    )),

    method_call_expression: $ => prec(14, seq(
      $._expression,
      ".",
      choice($._name, "await"),
      optional(seq("::<", commaSep1($, $._generic_arg), ">")),
      "(",
      commaSep($, choice($.named_argument, $._expression, $.spread_argument)),
      ")",
    )),

    index_expression: $ => prec(PREC.postfix, seq($._index_receiver, "[", $._expression, "]")),

    _index_receiver: $ => choice(
      $._path,
      $.call_expression,
      $.try_expression,
      $.field_expression,
      $.method_call_expression,
      $.index_expression,
      $.array_expression,
      $.parenthesized_expression,
    ),

    tuple_expression: $ => choice(
      seq("(", ")"),
      seq("(", $._expression, choice(",", $._line_separator), commaSep($, $._expression), ")"),
    ),

    array_expression: $ => seq(
      "[",
      choice(
        commaSep($, $._expression),
        seq($._expression, ";", $._expression),
      ),
      "]",
    ),

    // `#[1, 2]` is a Vec and `[1, 2]` a fixed array; `#[0; 8]` repeats.
    vec_literal: $ => seq(
      "#[",
      choice(
        commaSep($, $._expression),
        seq($._expression, ";", $._expression),
      ),
      "]",
    ),

    set_literal: $ => seq(
      "#{",
      commaSep($, $._expression),
      "}",
    ),

    // A braced literal with `key: value` entries is a Map; the empty `{}`
    // is one too, so it outranks the empty block at the same position.
    map_literal: $ => prec(1, seq(
      "{",
      commaSep($, $.map_entry),
      "}",
    )),

    map_entry: $ => seq(
      field("key", $._expression),
      ":",
      field("value", $._expression),
    ),

    struct_expression: $ => seq(
      $._path,
      "{",
      commaSep($, choice(
        seq($._name, ":", $._expression),
        $.struct_spread_field,
        $._expression,
      )),
      "}",
    ),

    struct_spread_field: $ => prec(2, seq("..", $._expression)),

    if_expression: $ => prec.right(seq(
      "if",
      field("condition", choice($.let_chain_condition, $.let_condition, $._expression)),
      field("consequence", $.block),
      optional(seq("else", choice($.block, $.if_expression))),
    )),

    let_condition: $ => seq(
      "let",
      field("pattern", $._pattern),
      "=",
      field("value", $._condition_operand),
    ),

    _condition_operand: $ => prec(2, choice(
      $.literal,
      $._path,
      $.call_expression,
      $.generic_function,
      $.macro_invocation,
      $.try_expression,
      $.field_expression,
      $.method_call_expression,
      $.index_expression,
      $.reference_expression,
      $.tuple_expression,
      $.array_expression,
      $.parenthesized_expression,
      $.match_expression,
    )),

    let_chain_condition: $ => choice(
      seq(
        $.let_condition,
        repeat1(seq("&&", choice($.let_condition, $._expression))),
      ),
      seq(
        $._expression,
        "&&",
        $.let_condition,
        repeat(seq("&&", choice($.let_condition, $._expression))),
      ),
    ),

    match_expression: $ => seq(
      "match",
      field("scrutinee", $._match_scrutinee),
      "{",
      repeat($.match_arm),
      "}",
    ),

    _match_scrutinee: $ => choice($._condition_operand, $.binary_expression, $.pipe_expression),

    // The comma after an arm is optional; newline-terminated arms parse.
    match_arm: $ => seq(
      $._pattern,
      optional(seq("if", $._expression)),
      "=>",
      field("value", $._expression),
      optional(choice(",", $._line_separator)),
    ),

    loop_expression: $ => seq("loop", $.block),

    while_expression: $ => seq(
      "while",
      field("condition", choice($.let_chain_condition, $.let_condition, $._expression)),
      $.block,
    ),

    for_expression: $ => seq(
      "for",
      field("pattern", $._pattern),
      "in",
      field("iterable", $._expression),
      $.block,
    ),

    labelled_loop_expression: $ => seq(
      $.label,
      ":",
      choice($.loop_expression, $.while_expression, $.for_expression),
    ),

    return_expression: $ => prec.right(seq("return", optional($._expression))),

    break_expression: $ => prec.right(seq("break", optional($.label), optional($._expression))),

    continue_expression: $ => prec.right(seq("continue", optional($.label))),

    defer_expression: $ => prec.right(seq("defer", $._expression)),

    unsafe_expression: $ => seq("unsafe", $.block),

    comptime_expression: $ => seq("comptime", $.block),

    select_expression: $ => seq("select", "{", commaSep($, $.select_arm), "}"),

    select_arm: $ => seq(
      choice(
        seq($._pattern, "=", $._expression),
        "default",
        "else",
        $._expression,
      ),
      "=>",
      $._expression,
    ),

    closure_expression: $ => choice(
      prec.right(PREC.closure, seq(
        field("parameters", $.closure_parameters),
        optional(seq("->", field("return_type", $._type))),
        field("body", $._expression),
      )),
      seq(
        "fn",
        field("parameters", $.parameters),
        optional(seq("->", field("return_type", $._type))),
        field("body", $.block),
      ),
    ),

    closure_parameters: $ => choice(
      "||",
      seq("|", commaSep($, $.closure_parameter), "|"),
    ),

    // Or-patterns are excluded: a bare `|` closes the parameter list.
    closure_parameter: $ => seq(
      field("pattern", choice(
        $.tuple_pattern,
        $.reference_pattern,
        "_",
        $._name,
      )),
      optional(seq(":", field("type", $._type))),
    ),
  },
});


// A newline separates elements wherever a comma could, so a line break
// between two elements stands in for the comma: `gos fmt` writes commas on
// one line and newlines when multiline. `$._line_separator` is the
// zero-width token src/scanner.c emits at such a break.
function commaSep($, rule) {
  return optional(commaSep1($, rule));
}
function commaSep1($, rule) {
  return seq(
    rule,
    repeat(seq(choice(",", $._line_separator), rule)),
    optional(","),
  );
}
