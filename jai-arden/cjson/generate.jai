#run build();

build :: () {
    set_build_options_dc(.{do_output=false});

    options := get_build_options();
    extra: [] string;
    #if OS == .MACOS {
        macos_version_arg := tprint("-mmacosx-version-min=%.%", options.minimum_os_version.major, options.minimum_os_version.minor);
        extra = .[macos_version_arg];
    }
    success := build_cpp_dynamic_lib("cjson", "cjson.c", debug=true, extra = extra);
    if !success {
        compiler_set_workspace_status(.FAILED);
        return;
    }

    if !generate_bindings() {
        compiler_set_workspace_status(.FAILED);
        return;
    }
}

generate_bindings :: () -> bool {
    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {
            output_filename          = "windows.jai";
            strip_flags = 0;
        } else #if OS == .LINUX {
            output_filename          = "linux.jai";
            strip_flags = .INLINED_FUNCTIONS; // Inlined constructor doesn't exist in the library
        } else #if OS == .MACOS {
            output_filename          = "macos.jai";
            strip_flags = .INLINED_FUNCTIONS; // Inlined constructor doesn't exist in the library
        } else {
            assert(false);
        }

        array_add(*libraries,      .{filename="cjson"});
        array_add(*source_files,  "cjson.h");
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN");
    }

    return generate_bindings(opts, output_filename);
}

#scope_file

#import "Basic";
#import "Compiler";
#import "BuildCpp";
#import "Check";
#import "Bindings_Generator";
#import "File";
