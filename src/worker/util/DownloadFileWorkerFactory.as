package worker.util {
import flash.filesystem.File;

import worker.vo.DownloadFileDescriptor;

public class DownloadFileWorkerFactory {
    public static const FLEX_SDK:String = "FLEX_SDK";
    public static const UTORRENT:String = "UTORRENT";

    private static const FLEX_SDK_URL:String = "http://www.motorlogy.com/apache/flex/4.10.0/binaries/apache-flex-sdk-4.10.0-bin.zip";
    private static const UTORRENT_URL:String = "http://download-new.utorrent.com/endpoint/utorrent/os/windows/track/stable/";

    private static const FLEX_SDK_FILE_TARGET:String = "flexSDK_4.10.zip";
    private static const UTORRENT_FILE_TARGET:String = "utorrent.exe";

    private static var __cacheDir:File;
    private static var __initialized:Boolean = initialize();

    public static function create(kind:String, bindTo:IDownloadFileWorkerUIBinder = null, ...decorators):IDownloadFileWorker {
        var fileDescriptor:DownloadFileDescriptor;
        var fileTarget:File;
        var downloader:IDownloadFileWorker;

        switch (kind) {

            case FLEX_SDK:
                fileTarget = __cacheDir.resolvePath(FLEX_SDK_FILE_TARGET);
                fileDescriptor = new DownloadFileDescriptor(FLEX_SDK_URL, fileTarget.nativePath, 1);
                downloader = bindTo ?
                        new DownloadFileWorkerProxy(FLEX_SDK, fileDescriptor, bindTo.onProgress, bindTo.onError, bindTo.onCompleted) :
                        new DownloadFileWorkerProxy(FLEX_SDK, fileDescriptor);
                break;

            case UTORRENT:
                fileTarget = __cacheDir.resolvePath(UTORRENT_FILE_TARGET);
                fileDescriptor = new DownloadFileDescriptor(UTORRENT_URL, fileTarget.nativePath, 0);
                downloader = bindTo ?
                        new DownloadFileWorkerProxy(UTORRENT, fileDescriptor, bindTo.onProgress, bindTo.onError, bindTo.onCompleted) :
                        new DownloadFileWorkerProxy(UTORRENT, fileDescriptor);
                break;

            default:
                return null;
        }

        for each (var clazz:Class in decorators)
            downloader = new clazz(downloader);

        if (bindTo)
            bindTo.downloader = downloader;

        return downloader;
    }

    private static function initialize():Boolean {
        DownloadFileWorkerRegisterUtil.registerClassAliases();
        createCache();

        return true;
    }

    private static function createCache():void {
        __cacheDir = File.desktopDirectory.resolvePath("cache");
        if (!__cacheDir.exists)
            __cacheDir.createDirectory();
    }
}
}