from lark import Lark, Transformer, v_args

# Grammar definition with proper operator precedence hierarchy
# Precedence (lowest to highest): ampersand, additive, multiplicative, power, atom
grammar = r"""
start: code

code: statementblock

statementblock: statement*

statement: write_stmt
         | assign_stmt

write_stmt: WRITE ampersand ";"

assign_stmt: IDENTIFIER ":=" ampersand ";"

?ampersand: ampersand "&" additive -> ampersand_op
          | additive

?additive: additive "+" multiplicative -> plus
         | additive "-" multiplicative -> minus
         | multiplicative

?multiplicative: multiplicative "*" power -> times
               | multiplicative "/" power -> divide
               | power

?power: atom "^" power -> power_op
      | atom

?atom: NUMTOKEN -> num
     | STRTOKEN -> str
     | IDENTIFIER -> var
     | "null" -> null_val
     | "true" -> true_val
     | "false" -> false_val
     | "(" ampersand ")"

NUMTOKEN: /\d+(\.\d+)?/
STRTOKEN: /"[^"]*"|'[^']*'/
IDENTIFIER: /[a-zA-Z_][a-zA-Z0-9_]*/
WRITE: "write"

%import common.WS
%ignore WS
"""


class JsonTransformer(Transformer):
    """Transform parse tree into JSON structure"""

    @v_args(inline=True)
    def var(self, identifier):
        return {
            "type": "VARIABLE",
            "name": str(identifier),
            "line": "0",  # Line info not available in pure Lark parsing
        }

    def null_val(self, items):
        return {"type": "NULL"}

    def true_val(self, items):
        return {"type": "TRUE"}

    def false_val(self, items):
        return {"type": "FALSE"}

    @v_args(inline=True)
    def num(self, token):
        return {"type": "NUMTOKEN", "value": str(token)}

    @v_args(inline=True)
    def str(self, token):
        value = str(token)
        if (value.startswith('"') and value.endswith('"')) or (
            value.startswith("'") and value.endswith("'")
        ):
            value = value[1:-1]
        return {"type": "STRTOKEN", "value": value}

    def _binary_op(self, op_name, items):
        return {"type": op_name, "arg": [items[0], items[1]]}

    @v_args(inline=True)
    def ampersand_op(self, a, b):
        return self._binary_op("AMPERSAND", [a, b])

    @v_args(inline=True)
    def plus(self, a, b):
        return self._binary_op("PLUS", [a, b])

    @v_args(inline=True)
    def minus(self, a, b):
        return self._binary_op("MINUS", [a, b])

    @v_args(inline=True)
    def times(self, a, b):
        return self._binary_op("TIMES", [a, b])

    @v_args(inline=True)
    def divide(self, a, b):
        return self._binary_op("DIVIDE", [a, b])

    @v_args(inline=True)
    def power_op(self, a, b):
        return self._binary_op("POWER", [a, b])

    @v_args(inline=True)
    def write_stmt(self, write_token, expr):
        # WRITE statement
        return {"type": "WRITE", "arg": expr}

    @v_args(inline=True)
    def assign_stmt(self, ident, expr):
        # Assignment statement: IDENTIFIER = expr
        return {"type": "ASSIGN", "ident": str(ident), "arg": expr}

    def statement(self, items):
        # Unwrap the statement from either write_stmt or assign_stmt
        return items[0]

    def statementblock(self, items):
        return {"type": "STATEMENTBLOCK", "statements": items}

    def code(self, items):
        return items[0]


def parse(input_text):
    """Parse input text and return Python dict"""
    parser = Lark(grammar, parser="lalr", transformer=JsonTransformer())
    try:
        result = parser.parse(input_text)
        return result
    except Exception as e:
        return {"error": True, "message": f"Parse error: {str(e)}"}


if __name__ == "__main__":
    # Test example
    test_input = """
    write 42;
    write "hello";
    write x;
    write 5 + 3;
    write 10 * 2 + 5;
    """

    result = parse(test_input)
    print(result)
