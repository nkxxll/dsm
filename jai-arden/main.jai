#import,file "tokenizer.jai";
#import,file "parser.jai";
#import,file "interpreter.jai";
#import,file "cjson/linux.jai";

// we need c_free to free the c string form the parser generator and cjson
crt :: #library,system "libc";
c_free :: (memory: *void) #foreign crt "free";

DEFAULT_INPUT :: #string DONE
trace 5;
trace "hello";
trace [1, 2, 3];
trace true;
trace null;
trace 2026-11-01T10:10:10;
trace ["1 + 2 =", 1 + 2];
trace 1 + 2;
trace 1 Day;
DONE


main :: () {
    args := get_command_line_arguments();
    
    input: string;
    if args.count > 1 {
        // Read file from command line argument
        filename := args[1];
        file_content, success := read_entire_file(filename);
        if !success {
            print("Error: Could not read file '%'\n", filename);
            return;
        }
        input = file_content;
    } else {
        input = DEFAULT_INPUT;
    }
    
    tokens := scan_tokens(input, false);
    defer free(tokens.data);

    json := token_list_to_json(tokens);
    print("JSON: %\n", json);
    defer free(json);

    ast := parse_json(json);
    print("AST: %\n", to_string(ast));
    defer c_free(ast);

    cjson := cJSON_Parse(ast);
    defer cJSON_Delete(cjson);

    interpret(cjson);
}

#import "Basic";
#import "File";
