package worker.util {
import flash.errors.IOError;
import flash.net.registerClassAlias;

import worker.vo.DownloadFileDescriptor;

public class DownloadFileWorkerRegisterUtil {
    public static function registerClassAliases():void {
        // Register our classes we are serializing
        registerClassAlias("Error", Error);
        registerClassAlias("ReferenceError", ReferenceError);
        registerClassAlias("ArgumentError", ArgumentError);
        registerClassAlias("TypeError", TypeError);
        registerClassAlias("SecurityError", SecurityError);
        registerClassAlias("flash.errors.IOError", IOError);
        registerClassAlias("worker.vo.DownloadFileDescriptor", DownloadFileDescriptor);
    }
}
}