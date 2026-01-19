//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



CJSON_VERSION_MAJOR :: 1;
CJSON_VERSION_MINOR :: 7;
CJSON_VERSION_PATCH :: 19;

cJSON_Invalid :: 0;
cJSON_False :: 1 << 0;
cJSON_True :: 1 << 1;
cJSON_NULL :: 1 << 2;
cJSON_Number :: 1 << 3;
cJSON_String :: 1 << 4;
cJSON_Array :: 1 << 5;
cJSON_Object :: 1 << 6;
cJSON_Raw :: 1 << 7;

cJSON_IsReference :: 256;
cJSON_StringIsConst :: 512;

CJSON_NESTING_LIMIT :: 1000;

CJSON_CIRCULAR_LIMIT :: 10000;

/* The cJSON structure: */
cJSON :: struct {
    /* next/prev allow you to walk array/object chains. Alternatively, use GetArraySize/GetArrayItem/GetObjectItem */
    next:        *cJSON;
    prev:        *cJSON;

    /* An array or object item will have a child pointer pointing to a chain of the items in the array/object. */
    child:       *cJSON;

    /* The type of the item, as above. */
    type:        s32;

    /* The item's string, if type==cJSON_String  and type == cJSON_Raw */
    valuestring: *u8;

    /* writing to valueint is DEPRECATED, use cJSON_SetNumberValue instead */
    valueint:    s32;

    /* The item's number, if type==cJSON_Number */
    valuedouble: float64;

    /* The item's name string, if this item is the child of, or is in the list of subitems of an object. */
    _string:     *u8;
}

cJSON_Hooks :: struct {
    /* malloc/free are CDECL on Windows regardless of the default calling convention of the compiler, so ensure the hooks allow passing those functions directly. */
    malloc_fn: #type (sz: u64) -> *void #c_call;
    free_fn:   #type (ptr: *void) -> void #c_call;
}

cJSON_bool :: s32;

/* returns the version of cJSON as a string */
cJSON_Version :: () -> *u8 #foreign cjson;

/* Supply malloc, realloc and free functions to cJSON */
cJSON_InitHooks :: (hooks: *cJSON_Hooks) -> void #foreign cjson;

/* Memory Management: the caller is always responsible to free the results from all variants of cJSON_Parse (with cJSON_Delete) and cJSON_Print (with stdlib free, cJSON_Hooks.free_fn, or cJSON_free as appropriate). The exception is cJSON_PrintPreallocated, where the caller has full responsibility of the buffer. */
/* Supply a block of JSON, and this returns a cJSON object you can interrogate. */
cJSON_Parse :: (value: *u8) -> *cJSON #foreign cjson;
cJSON_ParseWithLength :: (value: *u8, buffer_length: u64) -> *cJSON #foreign cjson;

/* ParseWithOpts allows you to require (and check) that the JSON is null terminated, and to retrieve the pointer to the final byte parsed. */
/* If you supply a ptr in return_parse_end and parsing fails, then return_parse_end will contain a pointer to the error so will match cJSON_GetErrorPtr(). */
cJSON_ParseWithOpts :: (value: *u8, return_parse_end: **u8, require_null_terminated: cJSON_bool) -> *cJSON #foreign cjson;
cJSON_ParseWithLengthOpts :: (value: *u8, buffer_length: u64, return_parse_end: **u8, require_null_terminated: cJSON_bool) -> *cJSON #foreign cjson;

/* Render a cJSON entity to text for transfer/storage. */
cJSON_Print :: (item: *cJSON) -> *u8 #foreign cjson;

/* Render a cJSON entity to text for transfer/storage without any formatting. */
cJSON_PrintUnformatted :: (item: *cJSON) -> *u8 #foreign cjson;

/* Render a cJSON entity to text using a buffered strategy. prebuffer is a guess at the final size. guessing well reduces reallocation. fmt=0 gives unformatted, =1 gives formatted */
cJSON_PrintBuffered :: (item: *cJSON, prebuffer: s32, fmt: cJSON_bool) -> *u8 #foreign cjson;

/* Render a cJSON entity to text using a buffer already allocated in memory with given length. Returns 1 on success and 0 on failure. */
/* NOTE: cJSON is not always 100% accurate in estimating how much memory it will use, so to be safe allocate 5 bytes more than you actually need */
cJSON_PrintPreallocated :: (item: *cJSON, buffer: *u8, length: s32, format: cJSON_bool) -> cJSON_bool #foreign cjson;

/* Delete a cJSON entity and all subentities. */
cJSON_Delete :: (item: *cJSON) -> void #foreign cjson;

/* Returns the number of items in an array (or object). */
cJSON_GetArraySize :: (array: *cJSON) -> s32 #foreign cjson;

/* Retrieve item number "index" from array "array". Returns NULL if unsuccessful. */
cJSON_GetArrayItem :: (array: *cJSON, index: s32) -> *cJSON #foreign cjson;

/* Get item "string" from object. Case insensitive. */
cJSON_GetObjectItem :: (object: *cJSON, _string: *u8) -> *cJSON #foreign cjson;
cJSON_GetObjectItemCaseSensitive :: (object: *cJSON, _string: *u8) -> *cJSON #foreign cjson;
cJSON_HasObjectItem :: (object: *cJSON, _string: *u8) -> cJSON_bool #foreign cjson;

/* For analysing failed parses. This returns a pointer to the parse error. You'll probably need to look a few chars back to make sense of it. Defined when cJSON_Parse() returns 0. 0 when cJSON_Parse() succeeds. */
cJSON_GetErrorPtr :: () -> *u8 #foreign cjson;

/* Check item type and return its value */
cJSON_GetStringValue :: (item: *cJSON) -> *u8 #foreign cjson;
cJSON_GetNumberValue :: (item: *cJSON) -> float64 #foreign cjson;

/* These functions check the type of an item */
cJSON_IsInvalid :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsFalse :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsTrue :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsBool :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsNull :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsNumber :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsString :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsArray :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsObject :: (item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_IsRaw :: (item: *cJSON) -> cJSON_bool #foreign cjson;

/* These calls create a cJSON item of the appropriate type. */
cJSON_CreateNull :: () -> *cJSON #foreign cjson;
cJSON_CreateTrue :: () -> *cJSON #foreign cjson;
cJSON_CreateFalse :: () -> *cJSON #foreign cjson;
cJSON_CreateBool :: (boolean: cJSON_bool) -> *cJSON #foreign cjson;
cJSON_CreateNumber :: (num: float64) -> *cJSON #foreign cjson;
cJSON_CreateString :: (_string: *u8) -> *cJSON #foreign cjson;

/* raw json */
cJSON_CreateRaw :: (raw: *u8) -> *cJSON #foreign cjson;
cJSON_CreateArray :: () -> *cJSON #foreign cjson;
cJSON_CreateObject :: () -> *cJSON #foreign cjson;

/* Create a string where valuestring references a string so
* it will not be freed by cJSON_Delete */
cJSON_CreateStringReference :: (_string: *u8) -> *cJSON #foreign cjson;

/* Create an object/array that only references it's elements so
* they will not be freed by cJSON_Delete */
cJSON_CreateObjectReference :: (child: *cJSON) -> *cJSON #foreign cjson;
cJSON_CreateArrayReference :: (child: *cJSON) -> *cJSON #foreign cjson;

/* These utilities create an Array of count items.
* The parameter count cannot be greater than the number of elements in the number array, otherwise array access will be out of bounds.*/
cJSON_CreateIntArray :: (numbers: *s32, count: s32) -> *cJSON #foreign cjson;
cJSON_CreateFloatArray :: (numbers: *float, count: s32) -> *cJSON #foreign cjson;
cJSON_CreateDoubleArray :: (numbers: *float64, count: s32) -> *cJSON #foreign cjson;
cJSON_CreateStringArray :: (strings: **u8, count: s32) -> *cJSON #foreign cjson;

/* Append item to the specified array/object. */
cJSON_AddItemToArray :: (array: *cJSON, item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_AddItemToObject :: (object: *cJSON, _string: *u8, item: *cJSON) -> cJSON_bool #foreign cjson;

/* Use this when string is definitely const (i.e. a literal, or as good as), and will definitely survive the cJSON object.
* WARNING: When this function was used, make sure to always check that (item->type & cJSON_StringIsConst) is zero before
* writing to `item->string` */
cJSON_AddItemToObjectCS :: (object: *cJSON, _string: *u8, item: *cJSON) -> cJSON_bool #foreign cjson;

/* Append reference to item to the specified array/object. Use this when you want to add an existing cJSON to a new cJSON, but don't want to corrupt your existing cJSON. */
cJSON_AddItemReferenceToArray :: (array: *cJSON, item: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_AddItemReferenceToObject :: (object: *cJSON, _string: *u8, item: *cJSON) -> cJSON_bool #foreign cjson;

/* Remove/Detach items from Arrays/Objects. */
cJSON_DetachItemViaPointer :: (parent: *cJSON, item: *cJSON) -> *cJSON #foreign cjson;
cJSON_DetachItemFromArray :: (array: *cJSON, which: s32) -> *cJSON #foreign cjson;
cJSON_DeleteItemFromArray :: (array: *cJSON, which: s32) -> void #foreign cjson;
cJSON_DetachItemFromObject :: (object: *cJSON, _string: *u8) -> *cJSON #foreign cjson;
cJSON_DetachItemFromObjectCaseSensitive :: (object: *cJSON, _string: *u8) -> *cJSON #foreign cjson;
cJSON_DeleteItemFromObject :: (object: *cJSON, _string: *u8) -> void #foreign cjson;
cJSON_DeleteItemFromObjectCaseSensitive :: (object: *cJSON, _string: *u8) -> void #foreign cjson;

/* Update array items. */
cJSON_InsertItemInArray :: (array: *cJSON, which: s32, newitem: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_ReplaceItemViaPointer :: (parent: *cJSON, item: *cJSON, replacement: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_ReplaceItemInArray :: (array: *cJSON, which: s32, newitem: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_ReplaceItemInObject :: (object: *cJSON, _string: *u8, newitem: *cJSON) -> cJSON_bool #foreign cjson;
cJSON_ReplaceItemInObjectCaseSensitive :: (object: *cJSON, _string: *u8, newitem: *cJSON) -> cJSON_bool #foreign cjson;

/* Duplicate a cJSON item */
cJSON_Duplicate :: (item: *cJSON, recurse: cJSON_bool) -> *cJSON #foreign cjson;

/* Duplicate will create a new, identical cJSON item to the one you pass, in new memory that will
* need to be released. With recurse!=0, it will duplicate any children connected to the item.
* The item->next and ->prev pointers are always zero on return from Duplicate. */
/* Recursively compare two cJSON items for equality. If either a or b is NULL or invalid, they will be considered unequal.
* case_sensitive determines if object keys are treated case sensitive (1) or case insensitive (0) */
cJSON_Compare :: (a: *cJSON, b: *cJSON, case_sensitive: cJSON_bool) -> cJSON_bool #foreign cjson;

/* Minify a strings, remove blank characters(such as ' ', '\t', '\r', '\n') from strings.
* The input pointer json cannot point to a read-only address area, such as a string constant,
* but should point to a readable and writable address area. */
cJSON_Minify :: (json: *u8) -> void #foreign cjson;

/* Helper functions for creating and adding items to an object at the same time.
* They return the added item or NULL on failure. */
cJSON_AddNullToObject :: (object: *cJSON, name: *u8) -> *cJSON #foreign cjson;
cJSON_AddTrueToObject :: (object: *cJSON, name: *u8) -> *cJSON #foreign cjson;
cJSON_AddFalseToObject :: (object: *cJSON, name: *u8) -> *cJSON #foreign cjson;
cJSON_AddBoolToObject :: (object: *cJSON, name: *u8, boolean: cJSON_bool) -> *cJSON #foreign cjson;
cJSON_AddNumberToObject :: (object: *cJSON, name: *u8, number: float64) -> *cJSON #foreign cjson;
cJSON_AddStringToObject :: (object: *cJSON, name: *u8, _string: *u8) -> *cJSON #foreign cjson;
cJSON_AddRawToObject :: (object: *cJSON, name: *u8, raw: *u8) -> *cJSON #foreign cjson;
cJSON_AddObjectToObject :: (object: *cJSON, name: *u8) -> *cJSON #foreign cjson;
cJSON_AddArrayToObject :: (object: *cJSON, name: *u8) -> *cJSON #foreign cjson;

/* helper for the cJSON_SetNumberValue macro */
cJSON_SetNumberHelper :: (object: *cJSON, number: float64) -> float64 #foreign cjson;

/* Change the valuestring of a cJSON_String object, only takes effect when type of object is cJSON_String */
cJSON_SetValuestring :: (object: *cJSON, valuestring: *u8) -> *u8 #foreign cjson;

/* malloc/free objects using the malloc/free functions that have been set with cJSON_InitHooks */
cJSON_malloc :: (size: u64) -> *void #foreign cjson;
cJSON_free :: (object: *void) -> void #foreign cjson;

#scope_file

#import "Basic"; // For assert

cjson :: #library "./cjson";

#run {
    {
        info := type_info(cJSON);
        for info.members {
            if it.name == {
                case "next";
                    assert(it.offset_in_bytes == 0, "cJSON.next has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON.next has unexpected size % instead of 8", it.type.runtime_size);
                case "prev";
                    assert(it.offset_in_bytes == 8, "cJSON.prev has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON.prev has unexpected size % instead of 8", it.type.runtime_size);
                case "child";
                    assert(it.offset_in_bytes == 16, "cJSON.child has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON.child has unexpected size % instead of 8", it.type.runtime_size);
                case "type";
                    assert(it.offset_in_bytes == 24, "cJSON.type has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "cJSON.type has unexpected size % instead of 4", it.type.runtime_size);
                case "valuestring";
                    assert(it.offset_in_bytes == 32, "cJSON.valuestring has unexpected offset % instead of 32", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON.valuestring has unexpected size % instead of 8", it.type.runtime_size);
                case "valueint";
                    assert(it.offset_in_bytes == 40, "cJSON.valueint has unexpected offset % instead of 40", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "cJSON.valueint has unexpected size % instead of 4", it.type.runtime_size);
                case "valuedouble";
                    assert(it.offset_in_bytes == 48, "cJSON.valuedouble has unexpected offset % instead of 48", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON.valuedouble has unexpected size % instead of 8", it.type.runtime_size);
                case "_string";
                    assert(it.offset_in_bytes == 56, "cJSON._string has unexpected offset % instead of 56", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON._string has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(cJSON) == 64, "cJSON has size % instead of 64", size_of(cJSON));
    }

    {
        info := type_info(cJSON_Hooks);
        for info.members {
            if it.name == {
                case "malloc_fn";
                    assert(it.offset_in_bytes == 0, "cJSON_Hooks.malloc_fn has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON_Hooks.malloc_fn has unexpected size % instead of 8", it.type.runtime_size);
                case "free_fn";
                    assert(it.offset_in_bytes == 8, "cJSON_Hooks.free_fn has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "cJSON_Hooks.free_fn has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(cJSON_Hooks) == 16, "cJSON_Hooks has size % instead of 16", size_of(cJSON_Hooks));
    }
}

