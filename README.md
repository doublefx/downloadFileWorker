downloadFileWorker
==================

Simple AIR application using a worker to download files with resuming capabilities

![ScreenShot](https://raw.github.com/doublefx/downloadFileWorker/master/DownloadFileWorkerDemo.jpg)

This Demo uses a Factory (DownloadFileWorkerFactory) to download 2 files (The Apache Flex SDK 4.10 and uTorrent).
The Apache Flex SDK 4.10 is on a server with resuming capabilities, uTorrent isn't.

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