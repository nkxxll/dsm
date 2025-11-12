from typing import Any, Dict, Optional, Union

from lark import Tree


class Value:
    """Runtime value representation"""

    pass


class NumberValue(Value):
    def __init__(self, value: float):
        self.value = value

    def __repr__(self):
        return f"NumberValue({self.value})"


class StringValue(Value):
    def __init__(self, value: str):
        self.value = value

    def __repr__(self):
        return f"StringValue({self.value!r})"


class BoolValue(Value):
    def __init__(self, value: bool):
        self.value = value

    def __repr__(self):
        return f"BoolValue({self.value})"


class UnitValue(Value):
    def __repr__(self):
        return "UnitValue()"


class ListValue(Value):
    def __init__(self, items: list):
        self.items = items

    def __repr__(self):
        return f"ListValue({self.items})"


def eval_node(
    node: Union[Dict[str, Any], Tree], env: Optional[Dict[str, Value]] = None
) -> Value:
    """Evaluate an AST node and return a Value"""
    if env is None:
        env = {}

    # Handle Tree objects from Lark parser
    if isinstance(node, Tree):
        # Tree has already been transformed to dict by JsonTransformer
        return eval_node(node.children[0] if node.children else {}, env)

    # Handle dict nodes
    node_type = node.get("type")

    if node_type == "STATEMENTBLOCK":
        statements = node.get("statements", [])
        for stmt in statements:
            eval_node(stmt, env)
        return UnitValue()

    elif node_type == "WRITE":
        arg = node.get("arg")
        value = eval_node(arg, env)
        write_value(value)
        return UnitValue()

    elif node_type == "ASSIGN":
        ident = node.get("ident", "")
        arg = node.get("arg")
        value = eval_node(arg, env)
        env[ident] = value
        return UnitValue()

    elif node_type == "PLUS":
        args = node.get("arg", [])
        left = eval_node(args[0], env)
        right = eval_node(args[1], env)
        if isinstance(left, NumberValue) and isinstance(right, NumberValue):
            return NumberValue(left.value + right.value)
        raise TypeError(f"Cannot add {type(left).__name__} and {type(right).__name__}")

    elif node_type == "MINUS":
        args = node.get("arg", [])
        left = eval_node(args[0], env)
        right = eval_node(args[1], env)
        if isinstance(left, NumberValue) and isinstance(right, NumberValue):
            return NumberValue(left.value - right.value)
        raise TypeError(
            f"Cannot subtract {type(right).__name__} from {type(left).__name__}"
        )

    elif node_type == "TIMES":
        args = node.get("arg", [])
        left = eval_node(args[0], env)
        right = eval_node(args[1], env)
        if isinstance(left, NumberValue) and isinstance(right, NumberValue):
            return NumberValue(left.value * right.value)
        raise TypeError(
            f"Cannot multiply {type(left).__name__} and {type(right).__name__}"
        )

    elif node_type == "DIVIDE":
        args = node.get("arg", [])
        left = eval_node(args[0], env)
        right = eval_node(args[1], env)
        if isinstance(left, NumberValue) and isinstance(right, NumberValue):
            if right.value == 0:
                raise ZeroDivisionError("Division by zero")
            return NumberValue(left.value / right.value)
        raise TypeError(
            f"Cannot divide {type(left).__name__} by {type(right).__name__}"
        )

    elif node_type == "POWER":
        args = node.get("arg", [])
        left = eval_node(args[0], env)
        right = eval_node(args[1], env)
        if isinstance(left, NumberValue) and isinstance(right, NumberValue):
            return NumberValue(left.value**right.value)
        raise TypeError(
            f"Cannot exponentiate {type(left).__name__} by {type(right).__name__}"
        )

    elif node_type == "AMPERSAND":
        args = node.get("arg", [])
        left = eval_node(args[0], env)
        right = eval_node(args[1], env)
        if isinstance(left, StringValue) and isinstance(right, StringValue):
            return StringValue(left.value + right.value)
        raise TypeError(
            f"Cannot concatenate {type(left).__name__} and {type(right).__name__}"
        )

    elif node_type == "STRTOKEN":
        value = node.get("value", "")
        return StringValue(value)

    elif node_type == "NUMTOKEN":
        value = node.get("value", "0")
        return NumberValue(float(value))

    elif node_type == "VARIABLE":
        name = node.get("name", "")
        if name in env:
            return env[name]
        raise NameError(f"Undefined variable: {name}")

    elif node_type == "NULL":
        return UnitValue()

    elif node_type == "TRUE":
        return BoolValue(True)

    elif node_type == "FALSE":
        return BoolValue(False)

    elif node_type == "LIST":
        items = node.get("arg", [])
        evaluated_items = [eval_node(item, env) for item in items]
        return ListValue(evaluated_items)

    else:
        raise ValueError(f"Unknown node type: {node_type}")


def write_value(value: Value) -> None:
    """Print a value to stdout"""
    if isinstance(value, NumberValue):
        # Format numbers without unnecessary decimals
        if value.value == int(value.value):
            print(int(value.value))
        else:
            print(value.value)
    elif isinstance(value, StringValue):
        print(value.value)
    elif isinstance(value, BoolValue):
        print("true" if value.value else "false")
    elif isinstance(value, UnitValue):
        print("null")
    elif isinstance(value, ListValue):
        formatted_items = []
        for item in value.items:
            if isinstance(item, NumberValue):
                formatted_items.append(str(item.value))
            elif isinstance(item, StringValue):
                formatted_items.append(item.value)
            elif isinstance(item, BoolValue):
                formatted_items.append("true" if item.value else "false")
            elif isinstance(item, UnitValue):
                formatted_items.append("null")
            elif isinstance(item, ListValue):
                formatted_items.append("[...]")
        print("[" + ", ".join(formatted_items) + "]")
    else:
        raise TypeError(f"Unknown value type: {type(value).__name__}")


def interpret(ast: Union[Dict[str, Any], Tree]) -> None:
    """Interpret an AST and execute it"""
    env = {}
    eval_node(ast, env)
