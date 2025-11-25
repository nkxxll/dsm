import time
from datetime import datetime, timezone
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


class TimeValue(Value):
    def __init__(self, timestamp: float):
        self.timestamp = timestamp

    def __repr__(self):
        return f"TimeValue({self.timestamp})"


def _is_truthy(value: Value) -> bool:
    """Evaluate truthiness of a value"""
    if isinstance(value, BoolValue):
        return value.value
    elif isinstance(value, NumberValue):
        return value.value != 0
    elif isinstance(value, UnitValue):
        return False
    else:
        return True


def timestamp_to_iso_string(timestamp: float) -> str:
    """Convert unix timestamp to ISO 8601 string (UTC)"""
    dt = datetime.fromtimestamp(timestamp, tz=timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def time_string_to_float(time_str: str) -> float:
    """Convert HH:MM or HH:MM:SS time string to unix timestamp (today's date)"""
    parts = time_str.split(":")
    try:
        if len(parts) == 2:
            hours, minutes = int(parts[0]), int(parts[1])
            seconds = 0
        elif len(parts) == 3:
            hours, minutes, seconds = int(parts[0]), int(parts[1]), int(parts[2])
        else:
            raise ValueError(f"Invalid time format: {time_str}")

        # Get today's date and create datetime with the specified time
        now = datetime.now()
        dt = now.replace(hour=hours, minute=minutes, second=seconds, microsecond=0)
        return dt.timestamp()
    except (ValueError, IndexError) as e:
        raise ValueError(f"Invalid time format: {time_str}") from e


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

    elif node_type == "TRACE":
        line = node.get("line", "0")
        arg = node.get("arg")
        value = eval_node(arg, env)
        print(f"Line {line}: ", end="")
        write_value(value)
        return UnitValue()

    elif node_type == "ASSIGN":
        ident = node.get("ident", "")
        arg = node.get("arg")
        value = eval_node(arg, env)
        env[ident] = value
        return UnitValue()

    elif node_type == "TIMEASSIGN":
        ident = node.get("ident", "")
        arg = node.get("arg")
        value = eval_node(arg, env)
        if isinstance(value, TimeValue):
            # Store the time value in the environment
            env[ident] = value
        else:
            raise TypeError("TIMEASSIGN requires a time value")
        return UnitValue()

    elif node_type == "IF":
        condition = node.get("condition")
        thenbranch = node.get("thenbranch")
        elsebranch = node.get("elsebranch")

        cond_value = eval_node(condition, env)
        is_true = _is_truthy(cond_value)

        if is_true:
            return eval_node(thenbranch, env)
        else:
            return eval_node(elsebranch, env)

    elif node_type == "FOR":
        varname = node.get("varname", "")
        expression = node.get("expression")
        statements = node.get("statements")

        iterable_value = eval_node(expression, env)
        if not isinstance(iterable_value, ListValue):
            raise TypeError("FOR loop requires a list")

        for item in iterable_value.items:
            env[varname] = item
            eval_node(statements, env)

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
        elif isinstance(left, StringValue) and isinstance(right, NumberValue):
            # Convert number to string for concatenation
            num_str = (
                str(int(right.value))
                if right.value == int(right.value)
                else str(right.value)
            )
            return StringValue(left.value + num_str)
        elif isinstance(left, NumberValue) and isinstance(right, StringValue):
            # Convert number to string for concatenation
            num_str = (
                str(int(left.value))
                if left.value == int(left.value)
                else str(left.value)
            )
            return StringValue(num_str + right.value)
        elif isinstance(left, NumberValue) and isinstance(right, NumberValue):
            # Convert both numbers to strings for concatenation
            left_str = (
                str(int(left.value))
                if left.value == int(left.value)
                else str(left.value)
            )
            right_str = (
                str(int(right.value))
                if right.value == int(right.value)
                else str(right.value)
            )
            return StringValue(left_str + right_str)
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

    elif node_type == "TIMETOKEN":
        time_str = node.get("value", "")
        timestamp = time_string_to_float(time_str)
        return TimeValue(timestamp)

    elif node_type == "NOW":
        return TimeValue(time.time())

    elif node_type == "CURRENTTIME":
        return TimeValue(time.time())

    elif node_type == "TIME":
        arg = node.get("arg")
        value = eval_node(arg, env)
        if isinstance(value, TimeValue):
            return value
        else:
            return UnitValue()

    elif node_type == "UPPERCASE":
        arg = node.get("arg")
        value = eval_node(arg, env)
        if isinstance(value, StringValue):
            return StringValue(value.value.upper())
        elif isinstance(value, ListValue):
            uppercased_items = []
            for item in value.items:
                if isinstance(item, StringValue):
                    uppercased_items.append(StringValue(item.value.upper()))
                else:
                    uppercased_items.append(item)
            return ListValue(uppercased_items)
        else:
            raise TypeError("UPPERCASE expects a string or list of strings")

    elif node_type == "MAXIMUM":
        arg = node.get("arg")
        value = eval_node(arg, env)
        if not isinstance(value, ListValue):
            raise TypeError("MAXIMUM expects a list")

        numbers = [item.value for item in value.items if isinstance(item, NumberValue)]
        if not numbers:
            raise TypeError("MAXIMUM requires a list with at least one number")

        return NumberValue(max(numbers))

    elif node_type == "AVERAGE":
        arg = node.get("arg")
        value = eval_node(arg, env)
        if not isinstance(value, ListValue):
            raise TypeError("AVERAGE expects a list")

        numbers = [item.value for item in value.items if isinstance(item, NumberValue)]
        if not numbers:
            raise TypeError("AVERAGE requires a list with at least one number")

        return NumberValue(sum(numbers) / len(numbers))

    elif node_type == "INCREASE":
        arg = node.get("arg")
        value = eval_node(arg, env)
        if not isinstance(value, ListValue):
            raise TypeError("INCREASE expects a list")

        # Extract only numeric items
        numbers = [item.value for item in value.items if isinstance(item, NumberValue)]

        # Calculate differences between consecutive elements
        if len(numbers) < 2:
            return ListValue([])

        differences = [
            NumberValue(numbers[i + 1] - numbers[i]) for i in range(len(numbers) - 1)
        ]
        return ListValue(differences)

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
    elif isinstance(value, TimeValue):
        print(timestamp_to_iso_string(value.timestamp))
    elif isinstance(value, ListValue):
        formatted_items = []
        for item in value.items:
            if isinstance(item, NumberValue):
                # Format numbers without unnecessary decimals
                if item.value == int(item.value):
                    formatted_items.append(str(int(item.value)))
                else:
                    formatted_items.append(str(item.value))
            elif isinstance(item, StringValue):
                formatted_items.append(item.value)
            elif isinstance(item, BoolValue):
                formatted_items.append("true" if item.value else "false")
            elif isinstance(item, UnitValue):
                formatted_items.append("null")
            elif isinstance(item, TimeValue):
                formatted_items.append(timestamp_to_iso_string(item.timestamp))
            elif isinstance(item, ListValue):
                formatted_items.append("[...]")
        print("[" + ", ".join(formatted_items) + "]")
    else:
        raise TypeError(f"Unknown value type: {type(value).__name__}")


def interpret(ast: Union[Dict[str, Any], Tree]) -> None:
    """Interpret an AST and execute it"""
    env = {}
    eval_node(ast, env)
