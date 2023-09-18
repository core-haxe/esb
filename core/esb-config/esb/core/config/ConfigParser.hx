package esb.core.config;

import esb.core.config.sections.EsbConfig;
using StringTools;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.ConfigParser")
extern class ConfigParser {
    public function new();
    public function parse(jsonString:String):EsbConfig;
    public static function fromFile(filename:String):EsbConfig;
}

#else

@:expose
@:native("esb.core.config.ConfigParser")
class ConfigParser {
    private var _cwd:String = null;

    public function new(cwd:String = null) {
        _cwd = cwd;
    }

    public function parse(jsonString:String):EsbConfig {
        var preprocessor = new ConfigPreProcessor(jsonString, _cwd);
        var json = preprocessor.process();
        //trace(json);

        var parser = new json2object.JsonParser<esb.core.config.sections.EsbConfig>();
        parser.fromJson(haxe.Json.stringify(json));
        var item:esb.core.config.sections.EsbConfig = parser.value;
        printErrors(parser.errors);
        @:privateAccess item.postProcess();
        return item;
    }

    private function printErrors(errors:Array<json2object.Error>) {
        if (errors != null) {
            for (error in errors) {
                switch (error) {
                    case IncorrectType(variable, expected, pos):
                        trace('WARNING: json2object.IncorrectType("${variable}", "${expected}")');
                    case IncorrectEnumValue(value, expected, pos):    
                        trace('WARNING: json2object.IncorrectEnumValue("${value}", "${expected}")');
                    case InvalidEnumConstructor(value, expected, pos):    
                        trace('WARNING: json2object.InvalidEnumConstructor("${value}", "${expected}")');
                    case UninitializedVariable(variable, pos):    
                        //trace('WARNING: json2object.UninitializedVariable("${variable}")');
                    case UnknownVariable(variable, pos):    
                        trace('WARNING: json2object.UnknownVariable("${variable}")');
                    case ParserError(message, pos):    
                        trace('WARNING: json2object.ParserError("${message}")');
                    case CustomFunctionException(e, pos):    
                }
            }
        }
    }

    public static function fromFile(filename:String):EsbConfig {
        var parts = haxe.io.Path.normalize(filename).split("/");
        parts.pop();
        var cwd = Sys.getCwd() + "/" + parts.join("/");
        var contents = sys.io.File.getContent(filename);
        var config = new ConfigParser(cwd);
        return config.parse(contents);
    }
}

private class ConfigPreProcessor {
    private static var reg = new EReg("\\${(.*?)\\}", "gm");
    private var jsonString:String;
    private var result:Dynamic;

    public function new(jsonString:String, cwd:String = null) {
        this.jsonString = jsonString;
        this._cwd = cwd;
    }

    public function process():Dynamic {
        result = {};

        if (jsonString.contains("${") && jsonString.contains("}")) {
            jsonString = reg.map(jsonString, f -> {
                return handleVar(f.matched(1));
            });
        }


        try {
            var json = haxe.Json.parse(jsonString);
            processImportNodes(json);
            result = processNodes(json);
        } catch (e:Dynamic) {
            trace("ERROR: problem parsing json config: ", e);
        }

        return result;
    }

    private function handleVar(varName:String):String {
        if (varName.startsWith("env:")) {
            var name = varName.substr("env:".length);
            if (Sys.getEnv(name) == null) {
                trace('WARNING: could not resolve environment variable: ${name}');
            } else {
                return Sys.getEnv(name);
            }
        } else if (varName.startsWith("file:")) {
            var name = varName.substr("file:".length);
            var cwd = getCwd();
            var fullPath = haxe.io.Path.normalize(cwd + "/" + name);
            if (!sys.FileSystem.isDirectory(fullPath) && sys.FileSystem.exists(fullPath)) {
                return sys.io.File.getContent(fullPath).trim();
            } else {
                trace('WARNING: could not read file: ${name}');
            }
        } else {
            trace('WARNING: unknown variable type: ${varName}');
        }
        return null;
    }

    private function processImportNodes(json:Dynamic) {
        for (nodeName in Reflect.fields(json)) {
            var node = Reflect.field(json, nodeName);
            if (nodeName == "import") {
                handleImports(json, node);
            }

            switch (Type.typeof(node)) {
                case TObject:
                    processImportNodes(node);
                case _:    
            }
        }
    }

    private function processNode(node:Dynamic):Dynamic {
        var result:Dynamic = null;
        switch (Type.typeof(node)) {
            case TObject:
                result = processNodes(node);
            case TClass(Array):
                result = [];
                var nodeArray:Array<Dynamic> = node;
                for (item in nodeArray) {
                    result.push(processNode(item));
                }
            case TClass(String):    
                result = node;
            case TBool:
                result = node;
            case TInt:    
                result = node;
            case TFloat:    
                result = node;
            case _:    
                trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>> NO IDEA: ", Type.typeof(node));
        }
        return result;
    }

    private function processNodes(json:Dynamic):Dynamic {
        var result:Dynamic = null;
        for (nodeName in Reflect.fields(json)) {
            var node = Reflect.field(json, nodeName);
            if (result == null) {
                result = {};
            }

            if (nodeName != "import" && node != null) {
                Reflect.setField(result, nodeName, processNode(node));
            }
        }
        return result;
    }

    private function handleImports(json:Dynamic, importNames:Array<String>) {
        for (importName in importNames) {
            handleImport(json, importName);
        }
    }

    private function handleImport(json:Dynamic, importName:String) {
        if (importName.contains("*")) { // lets assume regex on files, little brittle

            var regex = new EReg(importName, "gm");
            var cwd = getCwd();
            for (item in sys.FileSystem.readDirectory(cwd)) {
                var fullPath = haxe.io.Path.normalize(cwd + "/" + item);
                if (!sys.FileSystem.isDirectory(fullPath) && regex.match(item)) {
                    handleImport(json, item);
                }
            }
        } else {
            var cwd = getCwd();
            var fullPath = haxe.io.Path.normalize(cwd + "/" + importName);
            if (!sys.FileSystem.exists(fullPath)) {
                trace('WARNING: ${importName} does not exist, skipping');
                return;
            }
            if (sys.FileSystem.isDirectory(fullPath)) {
                trace('WARNING: ${importName} is directory, skipping');
                return;
            }

            var jsonString = sys.io.File.getContent(fullPath);
            var preprocessor = new ConfigPreProcessor(jsonString, _cwd);
            var importedJson = preprocessor.process();
            mergeJson(json, importedJson);
        }
    }

    private function mergeJson(jsonDest:Dynamic, jsonSrc:Dynamic) {
        for (fieldNameSrc in Reflect.fields(jsonSrc)) {
            var fieldExistsInDest = Reflect.hasField(jsonDest, fieldNameSrc);
            var fieldValueSrc = Reflect.field(jsonSrc, fieldNameSrc);
            if (fieldExistsInDest) {
                var fieldTypeSrc = Type.typeof(fieldValueSrc);
                var fieldValueDest = Reflect.field(jsonDest, fieldNameSrc);
                var fieldTypeDest = Type.typeof(fieldValueDest);
                if (typeName(fieldValueSrc) != typeName(fieldValueDest)) {
                    trace('WARNING: type of fields dont match, skipping (field: ${fieldNameSrc}, ${typeName(fieldValueSrc)} != ${typeName(fieldValueDest)})');
                } else {
                    switch (fieldTypeSrc) {
                        case TObject:
                            mergeJson(fieldValueDest, fieldValueSrc);
                        case TClass(Array):
                            var arraySrc:Array<Dynamic> = fieldValueSrc;
                            var arrayDest:Array<Dynamic> = fieldValueDest;
                            for (item in arraySrc) {
                                arrayDest.push(item);
                            }
                        case _:    
                            trace('WARNING: primitive values wont be merged / overwritten, skipping (field: ${fieldNameSrc}, type: ${typeName(fieldValueSrc)})');
                    }
                }
            } else {
                Reflect.setField(jsonDest, fieldNameSrc, fieldValueSrc);
            }
        }
    }

    private function typeName(o:Dynamic):String {
        return switch (Type.typeof(o)) {
            case TObject:
                "object";
            case TClass(Array):
                "array";
            case TClass(String):    
                "string";
            case TBool:
                "bool";
            case TInt:    
                "int";
            case TFloat:    
                "float";
            case _:    
                trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>> NO IDEA: ", Type.typeof(o));
                "unknown";
        }
    }

    private var _cwd:String = null;
    private function getCwd():String {
        if (_cwd != null) {
            return _cwd;
        }
        return Sys.getCwd();
    }
}

#end