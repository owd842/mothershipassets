const path = require('node:path');
module.paths.push(path.resolve(__dirname, 'C:\\ProgramData\\owd\\node\\node-v26.4.0-win-x64\\node_modules'));

const koffi = require('koffi');

const lib = koffi.load('F:\\__Binaries\\MSVC\\pcmon.dll');

const myfunc = lib.func('__stdcall', 'pcmon_main', 'int', []);

myfunc();
