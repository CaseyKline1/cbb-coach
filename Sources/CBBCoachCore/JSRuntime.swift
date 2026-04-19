import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif

final class JSRuntime: @unchecked Sendable {
    static let shared = JSRuntime()

    #if canImport(JavaScriptCore)
    private let context: JSContext
    #endif

    private init() {
        #if canImport(JavaScriptCore)
        guard let context = JSContext() else {
            fatalError("Failed to create JavaScriptCore context")
        }
        self.context = context

        let exceptionHandler: @convention(block) (JSContext?, JSValue?) -> Void = { _, exception in
            if let exception {
                NSLog("JS exception: %@", String(describing: exception))
            }
        }
        context.exceptionHandler = exceptionHandler
        context.setObject(exceptionHandler, forKeyedSubscript: "__swiftExceptionHandler" as NSString)

        let readFile: @convention(block) (String) -> String = { path in
            (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        }
        let writeFile: @convention(block) (String, String) -> Void = { path, content in
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
        let mkdir: @convention(block) (String) -> Void = { path in
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        let nowISO: @convention(block) () -> String = {
            ISO8601DateFormatter().string(from: Date())
        }

        context.setObject(readFile, forKeyedSubscript: "__swiftReadFile" as NSString)
        context.setObject(writeFile, forKeyedSubscript: "__swiftWriteFile" as NSString)
        context.setObject(mkdir, forKeyedSubscript: "__swiftMkdir" as NSString)
        context.setObject(nowISO, forKeyedSubscript: "__swiftNowISO" as NSString)

        evaluateBootstrap(in: context)
        #endif
    }

    #if canImport(JavaScriptCore)
    private func evaluateBootstrap(in context: JSContext) {
        let playerSource = loadResourceText(name: "player", ext: "js")
        let coachSource = loadResourceText(name: "coach", ext: "js")
        let gameEngineSource = loadResourceText(name: "gameEngine.bundle", ext: "js")
        let leagueEngineSource = loadResourceText(name: "leagueEngine.bundle", ext: "js")
        let d1Snapshot = loadResourceText(name: "d1-conferences.2026", ext: "json")

        let bootstrap = """
        (function() {
          var __modules = {};
          var __handles = {};
          var __nextHandle = 1;

          function __storeHandle(value) {
            var handle = 'h' + (__nextHandle++);
            __handles[handle] = value;
            return handle;
          }

          function __getHandle(handle) {
            if (!__handles.hasOwnProperty(handle)) {
              throw new Error('Unknown handle: ' + handle);
            }
            return __handles[handle];
          }

          function __define(id, factory) {
            __modules[id] = { factory: factory, exports: {}, loaded: false };
          }

          function __require(id) {
            if (id === 'fs') {
              return {
                readFileSync: function(path, encoding) {
                  var text = __swiftReadFile(path);
                  return encoding === 'utf8' || encoding == null ? text : text;
                },
                writeFileSync: function(path, content) { __swiftWriteFile(path, String(content)); },
                mkdirSync: function(path, options) { __swiftMkdir(path); }
              };
            }

            if (id === 'path') {
              return {
                resolve: function() {
                  if (arguments.length === 0) return '';
                  return String(arguments[arguments.length - 1]);
                },
                dirname: function(path) {
                  var p = String(path || '');
                  var idx = p.lastIndexOf('/');
                  if (idx <= 0) return '.';
                  return p.slice(0, idx);
                },
                join: function() {
                  var out = [];
                  for (var i = 0; i < arguments.length; i++) {
                    out.push(String(arguments[i]));
                  }
                  return out.join('/').replace(/\\/+/g, '/');
                }
              };
            }

            var mod = __modules[id];
            if (!mod) throw new Error('Module not found: ' + id);
            if (!mod.loaded) {
              mod.loaded = true;
              var module = { exports: mod.exports };
              mod.factory(__require, module, mod.exports);
              mod.exports = module.exports;
            }
            return mod.exports;
          }

          var Buffer = { byteLength: function(str) { return unescape(encodeURIComponent(String(str))).length; } };
          var console = { log: function(){}, warn: function(){}, error: function(){} };

          __define('./data/d1-conferences.2026.json', function(require, module, exports) {
            module.exports = JSON.parse(\(jsonStringLiteral(d1Snapshot)));
          });

          __define('./player', function(require, module, exports) {
        \(playerSource)
          });

          __define('./coach', function(require, module, exports) {
        \(coachSource)
          });

          __define('./gameEngine', function(require, module, exports) {
        \(gameEngineSource)
          });

          __define('./leagueEngine', function(require, module, exports) {
        \(leagueEngineSource)
          });

          var __player = __require('./player');
          var __coach = __require('./coach');
          var __gameEngine = __require('./gameEngine');
          var __leagueEngine = __require('./leagueEngine');

          function __parse(str) { return JSON.parse(str); }
          function __stringify(v) { return JSON.stringify(v); }

          function __seededRandom(values) {
            var idx = 0;
            var vals = values || [];
            function r() {
              if (idx < vals.length) {
                var v = vals[idx];
                idx += 1;
                return v;
              }
              idx += 1;
              return Math.random();
            }
            r.__used = function() { return idx; };
            return r;
          }

          globalThis.__invoke = function(moduleId, fnName, argsJson) {
            var args = __parse(argsJson);
            var target = __require(moduleId);
            var result = target[fnName].apply(null, args);
            return __stringify(result);
          };

          globalThis.__invokeNew = function(moduleId, fnName, argsJson) {
            var args = __parse(argsJson);
            var target = __require(moduleId);
            var result = target[fnName].apply(null, args);
            return __stringify({ handle: __storeHandle(result) });
          };

          globalThis.__invokeWithRandom = function(moduleId, fnName, argsJson, randomValuesJson) {
            var args = __parse(argsJson);
            var rand = __seededRandom(__parse(randomValuesJson));
            args.push(rand);
            var target = __require(moduleId);
            var result = target[fnName].apply(null, args);
            return __stringify({ result: result, randomUsed: rand.__used() });
          };

          globalThis.__invokeNewWithRandom = function(moduleId, fnName, argsJson, randomValuesJson) {
            var args = __parse(argsJson);
            var rand = __seededRandom(__parse(randomValuesJson));
            args.push(rand);
            var target = __require(moduleId);
            var result = target[fnName].apply(null, args);
            return __stringify({ handle: __storeHandle(result), randomUsed: rand.__used() });
          };

          globalThis.__invokeMutableWithRandom = function(moduleId, fnName, firstArgJson, restArgsJson, randomValuesJson) {
            var first = __parse(firstArgJson);
            var rest = __parse(restArgsJson);
            var rand = __seededRandom(__parse(randomValuesJson));
            var args = [first].concat(rest);
            args.push(rand);
            var target = __require(moduleId);
            var ret = target[fnName].apply(null, args);
            return __stringify({ state: first, result: ret, randomUsed: rand.__used() });
          };

          globalThis.__invokeHandle = function(moduleId, fnName, handle, restArgsJson) {
            var first = __getHandle(handle);
            var rest = __parse(restArgsJson);
            var args = [first].concat(rest);
            var target = __require(moduleId);
            var ret = target[fnName].apply(null, args);
            return __stringify(ret);
          };

          globalThis.__invokeHandleMutable = function(moduleId, fnName, handle, restArgsJson) {
            var first = __getHandle(handle);
            var rest = __parse(restArgsJson);
            var args = [first].concat(rest);
            var target = __require(moduleId);
            var ret = target[fnName].apply(null, args);
            return __stringify(ret);
          };

          globalThis.__invokeHandleMutableWithRandom = function(moduleId, fnName, handle, restArgsJson, randomValuesJson) {
            var first = __getHandle(handle);
            var rest = __parse(restArgsJson);
            var rand = __seededRandom(__parse(randomValuesJson));
            var args = [first].concat(rest);
            args.push(rand);
            var target = __require(moduleId);
            var ret = target[fnName].apply(null, args);
            return __stringify({ result: ret, randomUsed: rand.__used() });
          };

          globalThis.__invokeMutable = function(moduleId, fnName, firstArgJson, restArgsJson) {
            var first = __parse(firstArgJson);
            var rest = __parse(restArgsJson);
            var args = [first].concat(rest);
            var target = __require(moduleId);
            var ret = target[fnName].apply(null, args);
            return __stringify({ state: first, result: ret });
          };

          globalThis.__snapshotHandle = function(handle) {
            var value = __getHandle(handle);
            return __stringify(value);
          };
        })();
        """

        context.evaluateScript(bootstrap)
    }

    private func loadResourceText(name: String, ext: String, subdir: String? = nil) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdir),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            let location = subdir.map { "\($0)/\(name).\(ext)" } ?? "\(name).\(ext)"
            fatalError("Missing resource \(location)")
        }
        return text
    }

    private func jsonStringLiteral(_ value: String) -> String {
        let data = try! JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8)!
    }

    private func call(functionName: String, args: [String]) throws -> String {
        guard let fn = context.objectForKeyedSubscript(functionName) else {
            throw NSError(domain: "CBBCoachCore", code: 910, userInfo: [NSLocalizedDescriptionKey: "JS function \(functionName) not found"])
        }
        let jsArgs: [Any] = args
        let result = fn.call(withArguments: jsArgs)
        if let exception = context.exception {
            throw NSError(domain: "CBBCoachCore", code: 911, userInfo: [NSLocalizedDescriptionKey: "JS exception: \(String(describing: exception))"])
        }
        guard let text = result?.toString() else {
            throw NSError(domain: "CBBCoachCore", code: 912, userInfo: [NSLocalizedDescriptionKey: "JS function \(functionName) did not return a string"])
        }
        return text
    }

    func invoke(moduleId: String, fn: String, args: [JSONValue]) throws -> JSONValue {
        let payload = try toJSONString(args)
        let raw = try call(functionName: "__invoke", args: [moduleId, fn, payload])
        return try fromJSONString(raw, as: JSONValue.self)
    }

    func invokeWithRandom(moduleId: String, fn: String, args: [JSONValue], random: inout SeededRandom) throws -> (result: JSONValue, randomUsed: Int) {
        let argsPayload = try toJSONString(args)
        let poolSize = 200_000
        var copy = random
        var values: [Double] = []
        values.reserveCapacity(poolSize)
        for _ in 0..<poolSize { values.append(copy.nextUnit()) }
        let valuesPayload = try toJSONString(values)
        let raw = try call(functionName: "__invokeWithRandom", args: [moduleId, fn, argsPayload, valuesPayload])

        struct Response: Codable { let result: JSONValue; let randomUsed: Int }
        let decoded: Response = try fromJSONString(raw)

        let used = max(0, decoded.randomUsed)
        for _ in 0..<used { _ = random.nextUnit() }
        return (decoded.result, used)
    }

    func invokeNew(moduleId: String, fn: String, args: [JSONValue]) throws -> String {
        let payload = try toJSONString(args)
        let raw = try call(functionName: "__invokeNew", args: [moduleId, fn, payload])
        struct Response: Codable { let handle: String }
        let decoded: Response = try fromJSONString(raw)
        return decoded.handle
    }

    func invokeNewWithRandom(moduleId: String, fn: String, args: [JSONValue], random: inout SeededRandom) throws -> (handle: String, randomUsed: Int) {
        let argsPayload = try toJSONString(args)
        let poolSize = 200_000
        var copy = random
        var values: [Double] = []
        values.reserveCapacity(poolSize)
        for _ in 0..<poolSize { values.append(copy.nextUnit()) }
        let valuesPayload = try toJSONString(values)
        let raw = try call(functionName: "__invokeNewWithRandom", args: [moduleId, fn, argsPayload, valuesPayload])

        struct Response: Codable { let handle: String; let randomUsed: Int }
        let decoded: Response = try fromJSONString(raw)
        let used = max(0, decoded.randomUsed)
        for _ in 0..<used { _ = random.nextUnit() }
        return (decoded.handle, used)
    }

    func invokeHandle(moduleId: String, fn: String, handle: String, restArgs: [JSONValue]) throws -> JSONValue {
        let restPayload = try toJSONString(restArgs)
        let raw = try call(functionName: "__invokeHandle", args: [moduleId, fn, handle, restPayload])
        return try fromJSONString(raw, as: JSONValue.self)
    }

    func invokeHandleMutable(moduleId: String, fn: String, handle: String, restArgs: [JSONValue]) throws -> JSONValue {
        let restPayload = try toJSONString(restArgs)
        let raw = try call(functionName: "__invokeHandleMutable", args: [moduleId, fn, handle, restPayload])
        return try fromJSONString(raw, as: JSONValue.self)
    }

    func invokeHandleMutableWithRandom(moduleId: String, fn: String, handle: String, restArgs: [JSONValue], random: inout SeededRandom) throws -> (result: JSONValue, randomUsed: Int) {
        let restPayload = try toJSONString(restArgs)
        let poolSize = 200_000
        var copy = random
        var values: [Double] = []
        values.reserveCapacity(poolSize)
        for _ in 0..<poolSize { values.append(copy.nextUnit()) }
        let valuesPayload = try toJSONString(values)
        let raw = try call(functionName: "__invokeHandleMutableWithRandom", args: [moduleId, fn, handle, restPayload, valuesPayload])
        struct Response: Codable { let result: JSONValue; let randomUsed: Int }
        let decoded: Response = try fromJSONString(raw)
        let used = max(0, decoded.randomUsed)
        for _ in 0..<used { _ = random.nextUnit() }
        return (decoded.result, used)
    }

    func snapshot(handle: String) throws -> JSONValue {
        let raw = try call(functionName: "__snapshotHandle", args: [handle])
        return try fromJSONString(raw, as: JSONValue.self)
    }

    func invokeMutableWithRandom(moduleId: String, fn: String, state: JSONValue, restArgs: [JSONValue], random: inout SeededRandom) throws -> (state: JSONValue, result: JSONValue, randomUsed: Int) {
        let statePayload = try toJSONString(state)
        let restPayload = try toJSONString(restArgs)

        let poolSize = 200_000
        var copy = random
        var values: [Double] = []
        values.reserveCapacity(poolSize)
        for _ in 0..<poolSize { values.append(copy.nextUnit()) }
        let valuesPayload = try toJSONString(values)

        let raw = try call(functionName: "__invokeMutableWithRandom", args: [moduleId, fn, statePayload, restPayload, valuesPayload])
        struct Response: Codable { let state: JSONValue; let result: JSONValue; let randomUsed: Int }
        let decoded: Response = try fromJSONString(raw)

        let used = max(0, decoded.randomUsed)
        for _ in 0..<used { _ = random.nextUnit() }
        return (decoded.state, decoded.result, used)
    }

    func invokeMutable(moduleId: String, fn: String, state: JSONValue, restArgs: [JSONValue]) throws -> (state: JSONValue, result: JSONValue) {
        let statePayload = try toJSONString(state)
        let restPayload = try toJSONString(restArgs)
        let raw = try call(functionName: "__invokeMutable", args: [moduleId, fn, statePayload, restPayload])
        struct Response: Codable { let state: JSONValue; let result: JSONValue }
        let decoded: Response = try fromJSONString(raw)
        return (decoded.state, decoded.result)
    }
    #else
    func invoke(moduleId: String, fn: String, args: [JSONValue]) throws -> JSONValue {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeWithRandom(moduleId: String, fn: String, args: [JSONValue], random: inout SeededRandom) throws -> (result: JSONValue, randomUsed: Int) {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeNew(moduleId: String, fn: String, args: [JSONValue]) throws -> String {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeNewWithRandom(moduleId: String, fn: String, args: [JSONValue], random: inout SeededRandom) throws -> (handle: String, randomUsed: Int) {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeHandle(moduleId: String, fn: String, handle: String, restArgs: [JSONValue]) throws -> JSONValue {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeHandleMutable(moduleId: String, fn: String, handle: String, restArgs: [JSONValue]) throws -> JSONValue {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeHandleMutableWithRandom(moduleId: String, fn: String, handle: String, restArgs: [JSONValue], random: inout SeededRandom) throws -> (result: JSONValue, randomUsed: Int) {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func snapshot(handle: String) throws -> JSONValue {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeMutableWithRandom(moduleId: String, fn: String, state: JSONValue, restArgs: [JSONValue], random: inout SeededRandom) throws -> (state: JSONValue, result: JSONValue, randomUsed: Int) {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }

    func invokeMutable(moduleId: String, fn: String, state: JSONValue, restArgs: [JSONValue]) throws -> (state: JSONValue, result: JSONValue) {
        throw NSError(domain: "CBBCoachCore", code: 999, userInfo: [NSLocalizedDescriptionKey: "JavaScriptCore unavailable on this platform"])
    }
    #endif
}

func toJSONValue<T: Encodable>(_ value: T) throws -> JSONValue {
    let text = try toJSONString(value)
    return try fromJSONString(text, as: JSONValue.self)
}

func fromJSONValue<T: Decodable>(_ value: JSONValue, as type: T.Type = T.self) throws -> T {
    let text = try toJSONString(value)
    return try fromJSONString(text, as: T.self)
}
