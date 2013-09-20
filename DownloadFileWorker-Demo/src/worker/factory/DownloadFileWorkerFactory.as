package worker.factory {
import domain.vo.DownloadFileDescriptor;

import flash.desktop.NativeApplication;
import flash.filesystem.File;
import flash.utils.Dictionary;

import infrastructure.worker.api.downloadFileWorker.IDownloadFileWorker;
import infrastructure.worker.api.downloadFileWorker.IDownloadFileWorkerUIBinder;
import infrastructure.worker.util.RegisterUtil;
import infrastructure.worker.util.db.Registry;

import worker.proxy.DownloadFileWorkerProxy;

public class DownloadFileWorkerFactory {
    public static const DATABASE_NAME:String = "DB.db";

    public static const FLEX_SDK:String = "FLEX_SDK";
    public static const GETFOLDERSIZE:String = "GETFOLDERSIZE";
    public static const UTORRENT:String = "UTORRENT";

    private static const FLEX_SDK_URL:String = "http://www.motorlogy.com/apache/flex/4.10.0/binaries/apache-flex-sdk-4.10.0-bin.zip";
    private static const GETFOLDERSIZE_URL:String = "http://www.thummerer-software-design.de/download/GetFoldersize.zip";
    private static const UTORRENT_URL:String = "http://download-new.utorrent.com/endpoint/utorrent/os/windows/track/stable/";

    private static const FLEX_SDK_FILE_TARGET:String = "flexSDK_4.10.zip";
    private static const GETFOLDERSIZE_FILE_TARGET:String = "GetFoldersize.zip";
    private static const UTORRENT_FILE_TARGET:String = "utorrent.exe";

    private static var __cacheDir:File;
    private static var __initialized:Boolean = initialize();

    private static var __downloaders:Dictionary;

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

            case GETFOLDERSIZE:
                fileTarget = __cacheDir.resolvePath(GETFOLDERSIZE_FILE_TARGET);
                fileDescriptor = new DownloadFileDescriptor(GETFOLDERSIZE_URL, fileTarget.nativePath, 1);
                downloader = bindTo ?
                        new DownloadFileWorkerProxy(GETFOLDERSIZE, fileDescriptor, bindTo.onProgress, bindTo.onError, bindTo.onCompleted) :
                        new DownloadFileWorkerProxy(GETFOLDERSIZE, fileDescriptor);
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

        if (decorators.length && decorators[0] is Array)
            decorators = decorators[0];

        for each (var decorator:Class in decorators)
            downloader = new decorator(downloader);

        if (bindTo)
            bindTo.downloader = downloader;

        __downloaders[downloader.workerName] = downloader;

        return downloader;
    }

    private static function initialize():Boolean {
        // Initialize the Registry and the DownloadFileWorkerProxy to use the application DataBase.
        DownloadFileWorkerProxy.dbPath = File.applicationStorageDirectory.resolvePath(DATABASE_NAME).nativePath;
        Registry.initialize(DownloadFileWorkerProxy.dbPath, NativeApplication.nativeApplication.applicationID);

        RegisterUtil.registerClassAliases();
        createCache();

        __downloaders = new Dictionary(true);

        return true;
    }

    private static function createCache():void {
        __cacheDir = File.desktopDirectory.resolvePath("cache");
        if (!__cacheDir.exists)
            __cacheDir.createDirectory();
    }

    public static function finalize():void {

        for each (var downloader:IDownloadFileWorker in __downloaders)
            downloader.terminate();

        Registry.close();
    }
}
}