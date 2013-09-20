package infrastructure.worker.impl.downloadFileWorker.util {
import domain.vo.DownloadFileDescriptor;

import flash.errors.IOError;
import flash.filesystem.File;
import flash.net.registerClassAlias;

public class RegisterUtil {
    public static function registerClassAliases():void {
        // Register our classes we are serializing
        registerClassAlias("Error", Error);
        registerClassAlias("ReferenceError", ReferenceError);
        registerClassAlias("ArgumentError", ArgumentError);
        registerClassAlias("TypeError", TypeError);
        registerClassAlias("SecurityError", SecurityError);
        registerClassAlias("flash.errors.IOError", IOError);
        registerClassAlias("domain.vo.DownloadFileDescriptor", DownloadFileDescriptor);
        registerClassAlias("flash.filesystem.File", File);
    }
}
}