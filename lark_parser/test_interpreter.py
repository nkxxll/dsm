import pytest
from io import StringIO
import sys
from interpreter import eval_node, write_value, StringValue, NumberValue, BoolValue, UnitValue


class TestStringConcatenationWithNumbers:
    """Test string concatenation with numbers using the & operator"""

    def test_string_and_number(self, capsys):
        """Test concatenating string & number"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "STRTOKEN", "value": "Value: "},
                {"type": "NUMTOKEN", "value": "42"}
            ]
        }
        env = {}
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "Value: 42"

    def test_number_and_string(self, capsys):
        """Test concatenating number & string"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "NUMTOKEN", "value": "42"},
                {"type": "STRTOKEN", "value": " is the answer"}
            ]
        }
        env = {}
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "42 is the answer"

    def test_string_concat_float(self, capsys):
        """Test concatenating string & float number"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "STRTOKEN", "value": "Pi is approximately "},
                {"type": "NUMTOKEN", "value": "3.14159"}
            ]
        }
        env = {}
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "Pi is approximately 3.14159"

    def test_string_and_arithmetic_expression(self, capsys):
        """Test concatenating string with result of arithmetic"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "STRTOKEN", "value": "Result: "},
                {
                    "type": "PLUS",
                    "arg": [
                        {"type": "NUMTOKEN", "value": "10"},
                        {"type": "NUMTOKEN", "value": "5"}
                    ]
                }
            ]
        }
        env = {}
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "Result: 15"

    def test_chained_concat_with_numbers(self, capsys):
        """Test chaining multiple & operations with numbers"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {
                    "type": "AMPERSAND",
                    "arg": [
                        {"type": "STRTOKEN", "value": "The answer is "},
                        {"type": "NUMTOKEN", "value": "42"}
                    ]
                },
                {"type": "STRTOKEN", "value": "!"}
            ]
        }
        env = {}
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "The answer is 42!"

    def test_number_concat_float_and_string(self, capsys):
        """Test concatenating float & string"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "NUMTOKEN", "value": "2.5"},
                {"type": "STRTOKEN", "value": " meters"}
            ]
        }
        env = {}
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "2.5 meters"

    def test_invalid_number_concat_throws_error(self):
        """Test that concatenating non-string/number types throws error"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "TRUE"},
                {"type": "NUMTOKEN", "value": "42"}
            ]
        }
        env = {}
        with pytest.raises(TypeError):
            eval_node(node, env)

    def test_invalid_string_concat_throws_error(self):
        """Test that concatenating incompatible types throws error"""
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "STRTOKEN", "value": "hello"},
                {"type": "TRUE"}
            ]
        }
        env = {}
        with pytest.raises(TypeError):
            eval_node(node, env)


class TestStringConcatenationWithVariables:
    """Test string concatenation with variables containing numbers"""

    def test_string_concat_with_number_variable(self):
        """Test concatenating string with a number variable"""
        env = {"x": NumberValue(42)}
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "STRTOKEN", "value": "x = "},
                {"type": "VARIABLE", "name": "x"}
            ]
        }
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "x = 42"

    def test_number_variable_concat_with_string(self):
        """Test concatenating number variable with string"""
        env = {"num": NumberValue(100)}
        node = {
            "type": "AMPERSAND",
            "arg": [
                {"type": "VARIABLE", "name": "num"},
                {"type": "STRTOKEN", "value": " percent"}
            ]
        }
        result = eval_node(node, env)
        assert isinstance(result, StringValue)
        assert result.value == "100 percent"
