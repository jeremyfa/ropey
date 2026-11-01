import TestUtil.TestFailure;

/**
 * Runs the ported ropey tests: every instance method whose name starts with
 * `test` in the classes below. An optional first argument filters tests by
 * substring of `Class.method`.
 */
class Main {

    static function main() {
        var classes:Array<Class<Dynamic>> = [
            RopeTests,
            SliceTests,
            IterTests,
            ChunkCursorTests,
            RopeBuilderTests,
            ExtraTests,
            StrUtilsTests,
            StrIndicesTests,
            TreeTests,
            PropTests,
        ];

        var filter = getFilter();
        var passed = 0;
        var failed = 0;
        var failures = [];

        for (cls in classes) {
            var className = Type.getClassName(cls);
            var fields = Type.getInstanceFields(cls).filter(f -> StringTools.startsWith(f, 'test'));
            fields.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
            for (field in fields) {
                var name = className + '.' + field;
                if (filter != null && name.indexOf(filter) == -1)
                    continue;
                var instance = Type.createInstance(cls, []);
                try {
                    Reflect.callMethod(instance, Reflect.field(instance, field), []);
                    passed++;
                }
                catch (e:TestFailure) {
                    failed++;
                    failures.push(name + ': ' + e.message);
                }
                catch (e:Dynamic) {
                    failed++;
                    failures.push(name + ': uncaught ' + Std.string(e));
                }
            }
        }

        for (f in failures)
            println('FAIL ' + f);
        println('ropey tests: ' + passed + ' passed, ' + failed + ' failed, ' + TestUtil.assertions + ' assertions');
        exit(failed == 0 ? 0 : 1);
    }

    static function getFilter():Null<String> {
        #if eval
        // On the interpreter, `Sys.args()` returns the compiler arguments.
        return haxe.macro.Compiler.getDefine('filter');
        #elseif sys
        var args = Sys.args();
        return args.length > 0 ? args[0] : null;
        #elseif js
        var args:Array<String> = js.Syntax.code('(typeof process !== "undefined" ? process.argv.slice(2) : [])');
        return args.length > 0 ? args[0] : null;
        #else
        return null;
        #end
    }

    static function println(s:String):Void {
        #if sys
        Sys.println(s);
        #elseif js
        js.Syntax.code('console.log({0})', s);
        #else
        trace(s);
        #end
    }

    static function exit(code:Int):Void {
        #if sys
        Sys.exit(code);
        #elseif js
        js.Syntax.code('if (typeof process !== "undefined") process.exitCode = {0}', code);
        #end
    }

}
