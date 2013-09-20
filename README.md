downloadFileWorker
==================

Simple AIR application using a worker to download files with resuming capabilities

![ScreenShot](https://raw.github.com/doublefx/downloadFileWorker/master/DownloadFileWorkerDemo.jpg)

This Demo uses a Factory (DownloadFileWorkerFactory) to download 3 files (The Apache Flex SDK 4.10, GetFolderSize and uTorrent).
The Apache Flex SDK 4.10 and GetFolderSize are on a server with resuming capabilities, uTorrent isn't.

For the purpose of this demo, I use a cache directory (currently the Desktop folder) to avoid downloading again
the same file, this option can be set to false before the download has started (IDownloadFileWorker.useCache = false).

You can extend this demo to give the user the ability to upload any file, to do this, see how it is
currently implemented in DownloadFileWorkerFactory, basically, it can be done in 2 lines:

- url: Url of the file you want to download or copy.
- fileTarget: The folder you want your downloaded file be copied into.
- id: Unique name of this Download.

```ActionScript
var fileDescriptor:DownloadFileDescriptor = new DownloadFileDescriptor(url, fileTarget);
var downloader:IDownloadFileWorker = new DownloadFileWorkerProxy(id, fileDescriptor);
```

You can then add event listeners to the downloader to receive ProgressEvent.PROGRESS, ErrorEvent.ERROR and
Event.COMPLETE events through its IEventDispatcher Interface or use its IDownloadFileWorker Interface to interact with.

Note: From now, even if you restart the Demo with the states pause + terminate, the application will keep the tracking
the downloads in pause, it uses SQLite under the wood to do so, see DownloadFileWorkerFactory to get how to set it,
basically, you don't have to take care, it can be done in 2 lines:

```ActionScript
DownloadFileWorkerProxy.dbPath = File.applicationStorageDirectory.resolvePath(DATABASE_NAME).nativePath;
Registry.initialize(DownloadFileWorkerProxy.dbPath, NativeApplication.nativeApplication.applicationID);
```