#import "String";
#import "Basic";

// FFI declarations for lemon parser
foreign :: #library "../lemon/bin/grammar";

parse_to_string :: (input: *u8) -> *u8 #foreign foreign;

// @warning returns a c string
parse_json :: (json_input: string) -> *u8 {
    // Call the C parser
    c_string := to_c_string(json_input);
    c_output := parse_to_string(c_string);
    if !c_output {
        return "ERROR: Parser returned null";
    }

    return c_output;
}
