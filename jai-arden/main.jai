#import,file "tokenizer.jai";
#import,file "parser.jai";
#import,file "interpreter.jai";
#import,file "cjson/linux.jai";

// we need c_free to free the c string form the parser generator and cjson
crt :: #library,system "libc";
c_free :: (memory: *void) #foreign crt "free";

USAGE :: #string DONE
usage:
<program> <input file>
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
        log_error("%", USAGE);
        exit(1);
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
