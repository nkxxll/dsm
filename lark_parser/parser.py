from lark import Lark, Transformer, Tree, v_args

# Grammar definition with proper operator precedence hierarchy
# Precedence (lowest to highest): ampersand, additive, multiplicative, power, atom
grammar = r"""
start: code

code: statementblock

statementblock: statement*

statement: write_stmt
         | assign_stmt
         | trace_stmt
         | if_stmt
         | for_stmt

write_stmt: WRITE expr ";"

assign_stmt: IDENTIFIER ":=" expr ";"

trace_stmt: TRACE expr ";"

if_stmt: IF expr THEN statementblock else_part? ENDIF ";"

else_part: ELSE statementblock

for_stmt: FOR IDENTIFIER IN expr DO statementblock ENDDO ";"

?expr: expr "&" additive -> ampersand_op
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
     | function_call
     | NOW -> now_op
     | CURRENTTIME -> currenttime_op
     | TIMETOKEN -> time_token
     | "[" "]" -> empty_list
     | "[" expr list_rest "]" -> non_empty_list
     | "(" expr ")"

function_call: UPPERCASE expr -> uppercase_op
             | MAXIMUM expr -> maximum_op
             | AVERAGE expr -> average_op
             | INCREASE expr -> increase_op
             | TIME expr -> time_op

list_rest: ("," expr)*

NUMTOKEN: /\d+(\.\d+)?/
STRTOKEN: /"[^"]*"|'[^']*'/
IDENTIFIER: /[a-zA-Z_][a-zA-Z0-9_]*/
WRITE: "write"i
TRACE: "trace"i
IF: "if"i
THEN: "then"i
ELSE: "else"i
ENDIF: "endif"i
FOR: "for"i
IN: "in"i
DO: "do"i
ENDDO: "enddo"i
NOW: "now"i
CURRENTTIME: "currenttime"i
TIME: "time"i
UPPERCASE: "uppercase"i
MAXIMUM: "maximum"i
AVERAGE: "average"i
INCREASE: "increase"i
TIMETOKEN: /\d{1,2}:\d{2}(:\d{2})?/

%import common.WS
%ignore WS
"""


class Transformer(Transformer):
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

    @v_args(inline=True)
    def time_token(self, token):
        return {"type": "TIMETOKEN", "value": str(token)}

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
    def uppercase_op(self, token, expr):
        return {"type": "UPPERCASE", "arg": expr}

    @v_args(inline=True)
    def maximum_op(self, token, expr):
        return {"type": "MAXIMUM", "arg": expr}

    @v_args(inline=True)
    def average_op(self, token, expr):
        return {"type": "AVERAGE", "arg": expr}

    @v_args(inline=True)
    def increase_op(self, token, expr):
        return {"type": "INCREASE", "arg": expr}

    def function_call(self, items):
        # function_call dispatches to its sub-rules which return dicts
        return items[0]

    @v_args(inline=True)
    def now_op(self):
        return {"type": "NOW"}

    @v_args(inline=True)
    def currenttime_op(self):
        return {"type": "CURRENTTIME"}

    @v_args(inline=True)
    def time_op(self, token, expr):
        return {"type": "TIME", "arg": expr}

    def empty_list(self, items):
        return {"type": "LIST", "arg": []}

    @v_args(inline=True)
    def non_empty_list(self, first_item, rest_items):
        # Combine first item with rest items
        all_items = [first_item] + rest_items
        return {"type": "LIST", "arg": all_items}

    def list_rest(self, items):
        # list_rest returns items from the ("," ampersand)* rule
        # Each match gives us an ampersand, so items is the list of ampersands
        return items

    @v_args(inline=True)
    def write_stmt(self, write_token, expr):
        # WRITE statement
        return {"type": "WRITE", "arg": expr}

    def trace_stmt(self, items):
        # items contains: [TRACE token, expression dict, ";"]
        # Extract line number from TRACE token and expression from dict
        trace_token = None
        expr = None

        for item in items:
            if isinstance(item, dict):
                expr = item
            elif hasattr(item, "type") and item.type == "TRACE":
                trace_token = item

        # Get line number from TRACE token's position
        line_num = (
            str(trace_token.line)
            if trace_token and hasattr(trace_token, "line")
            else "0"
        )

        return {"type": "TRACE", "line": line_num, "arg": expr}

    @v_args(inline=True)
    def assign_stmt(self, ident, expr):
        # Assignment statement: IDENTIFIER = expr
        return {"type": "ASSIGN", "ident": str(ident), "arg": expr}

    def if_stmt(self, items):
        # items: [IF token, condition_dict, THEN token, thenbranch_dict, [else_part_dict], ENDIF token, semicolon token]
        # Filter out dicts, collect in order
        dicts = []
        for i, item in enumerate(items):
            # print(f"  item {i}: {type(item).__name__} = {item if isinstance(item, dict) else str(item)[:20]}")
            if isinstance(item, dict):
                dicts.append(item)

        condition = dicts[0]
        thenbranch = dicts[1]
        # else_part will be the 3rd dict if it exists
        elsebranch = (
            dicts[2] if len(dicts) > 2 else {"type": "STATEMENTBLOCK", "statements": []}
        )

        return {
            "type": "IF",
            "condition": condition,
            "thenbranch": thenbranch,
            "elsebranch": elsebranch,
        }

    def else_part(self, items):
        # items: [ELSE token, statementblock dict]
        # Return only the dict
        return items[1]

    def for_stmt(self, items):
        # items contains: FOR token, IDENTIFIER token, IN token, expression, DO token, statementblock, ENDDO token, semicolon token
        # Extract IDENTIFIER token and dicts
        varname = None
        dicts_only = []
        for item in items:
            if hasattr(item, "type") and item.type == "IDENTIFIER":
                varname = str(item)
            elif isinstance(item, dict):
                dicts_only.append(item)

        expression = dicts_only[0]
        statements = dicts_only[1]
        return {
            "type": "FOR",
            "varname": varname,
            "expression": expression,
            "statements": statements,
        }

    def statement(self, items):
        # Unwrap the statement from any of the statement types
        return items[0]

    def statementblock(self, items):
        return {"type": "STATEMENTBLOCK", "statements": items}

    def code(self, items):
        # items[0] should be the statementblock dict
        return items[0]

    def start(self, items):
        # start wraps the code
        return items[0]


def parse(input_text):
    """Parse input text and return Python dict"""
    parser = Lark(grammar, parser="lalr", transformer=Transformer())
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
