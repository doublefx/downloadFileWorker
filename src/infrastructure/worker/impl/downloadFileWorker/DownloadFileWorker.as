package infrastructure.worker.impl.downloadFileWorker {
import domain.vo.DownloadFileDescriptor;

import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.HTTPStatusEvent;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.URLRequest;
import flash.net.URLRequestHeader;
import flash.net.URLStream;
import flash.system.System;
import flash.utils.ByteArray;
import flash.utils.clearInterval;
import flash.utils.setInterval;

import infrastructure.worker.api.downloadFileWorker.AbstractDownloadFileWorker;
import infrastructure.worker.impl.downloadFileWorker.util.db.Registry;

public class DownloadFileWorker extends AbstractDownloadFileWorker {

    protected var _fileDescriptor:DownloadFileDescriptor;
    protected var _useCache:Boolean = true;
    protected var _loader:URLStream = null;
    protected var _req:URLRequest = null;
    protected var _oldPercentLoaded:Number = 0;
    protected var _hasResumingCapabilities:Boolean;
    protected var _fs:FileStream;
    protected var _buf:ByteArray;
    protected var _offs:Number = 0;
    protected var _paused:Boolean;
    protected var _intervalId:uint;
    protected var _flushedBytes:Number = 0;

    function DownloadFileWorker():void {
        super(this);
    }

    override protected function handleCommandMessage(event:Event):void {
        super.handleCommandMessage(event);

        if (hasMessage)
            try {
                var message:* = getMessage();

                if (!_loader && message is Array && message.length == 2 && message[0] == DOWNLOAD_MESSAGE && message[1] is DownloadFileDescriptor) {
                    _fileDescriptor = message[1] as DownloadFileDescriptor;
                } else {

                    switch (message) {
                        case USE_CACHE_MESSAGE:
                        {
                            _useCache = getMessage();
                            break;
                        }
                        case PAUSE_MESSAGE:
                        {
                            pause();
                            while (_paused) {
                                var msg:* = getMessage(true);
                                if (msg == RESUME_MESSAGE) {
                                    resume();
                                    return;
                                } else if (msg == ABORT_MESSAGE) {
                                    abort();
                                    return;
                                }
                            }
                            break;
                        }
                        case ABORT_MESSAGE:
                        {
                            abort();
                            return;
                        }

                        default:
                        {
                            return;
                        }
                    }
                }

                if (_fileDescriptor && !_loader)
                    copyOrDownload();

            } catch (error:Error) {
                Registry.remove(_fileDescriptor);
                sendError(error);
            }
    }

    protected function copyOrDownload():void {
        var source:File;
        var fileTarget:File = new File(_fileDescriptor.fileTargetPath);

        if (fileTarget.exists) {
            if (!_useCache) {
                fileTarget.deleteFile();
                Registry.remove(_fileDescriptor);
            } else {
                _fileDescriptor.bytesLoaded = _fileDescriptor.bytesTotal = fileTarget.size;
                Registry.load(_fileDescriptor);

                sendProgress(_fileDescriptor);

                if (_fileDescriptor.bytesLoaded == _fileDescriptor.bytesTotal) {
                    sendResult(_fileDescriptor);
                    return;
                }
            }
        }

        if (_fileDescriptor.fileUrl.search("http") == 0) {
            download(_fileDescriptor.fileUrl);
        } else if (_fileDescriptor.fileUrl.search("file://") == 0) {
            download(_fileDescriptor.fileUrl);
        } else {
            source = new File(_fileDescriptor.fileUrl);

            try {
                source.copyTo(fileTarget, true);
                _fileDescriptor.bytesLoaded = _fileDescriptor.bytesTotal = fileTarget.size;
                sendProgress(_fileDescriptor);
                sendResult(_fileDescriptor);
            } catch (error:Error) {
                sendError(error);
            }
        }
    }

    protected function download(url:String):void {
        _loader = new URLStream();
        _req = new URLRequest(url + "?" + new Date().getTime());

        if (_fileDescriptor.bytesLoaded > 0) {
            _offs = _flushedBytes = _fileDescriptor.bytesLoaded;
            _req.requestHeaders = [new URLRequestHeader("Range", "bytes=" + _offs + "-")];
        }

        //Wait for 5 minutes before aborting download attempt.  Adobe download sites as well as some Apache mirrors are extremely slow.
        _req.idleTimeout = 300000;

        _buf = new ByteArray();
        _paused = false;

        _loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onDownloadResponseStatus);

        _loader.addEventListener(ErrorEvent.ERROR, handleDownloadError, false, 0, true);
        _loader.addEventListener(IOErrorEvent.IO_ERROR, handleDownloadError, false, 0, true);
        _loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleDownloadError, false, 0, true);

        _loader.addEventListener(ProgressEvent.PROGRESS, handleDownloadProgress, false, 0, true);
        _loader.addEventListener(Event.COMPLETE, handleDownloadComplete, false, 0, true);

        _loader.load(_req);

        _intervalId = setInterval(flushPartialDownloadToMemory, 500);
    }

    protected function pause():void {
        _paused = true;
    }

    protected function resume():void {
        _req.requestHeaders = [new URLRequestHeader("Range", "bytes=" + _offs + "-")];
        _loader.load(_req);
        _paused = false;
        _intervalId = setInterval(flushPartialDownloadToMemory, 500);
    }

    protected function onDownloadResponseStatus(event:HTTPStatusEvent):void {
        addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onDownloadResponseStatus);
        var header:URLRequestHeader;

        if (event.status == 200 || event.status == 206)
            for each (header in event.responseHeaders) {
                if (header.name == "Accept-Ranges" && header.value == "bytes") {
                    _hasResumingCapabilities = true;
                    sendStatus(AbstractDownloadFileWorker.RESUMABLE_STATUS);
                    break
                }
            }
    }

    protected function handleDownloadProgress(event:ProgressEvent):void {
        if (_fileDescriptor.bytesTotal == 0) {
            _fileDescriptor.bytesTotal = event.bytesTotal;
        }
        sendProgressAtTick();
    }

    protected function handleDownloadError(event:ErrorEvent):void {
        sendError(new Error(event.text, event.errorID));
    }

    protected function handleDownloadComplete(event:Event):void {
        flushLastBytes();
        sendProgressAtTick();
        writeFileTarget();
        sendResult(_fileDescriptor);
    }

    protected function abort():void {

        clearInterval(_intervalId);

        var isDownloadCompleted:Boolean = _fileDescriptor.bytesLoaded == _fileDescriptor.bytesTotal;

        if (isDownloadCompleted) {
            Registry.remove(_fileDescriptor);
        } else if (_hasResumingCapabilities && _paused) {
            flushLastBytes();
            sendProgressAtTick();
            writeFileTarget();
            Registry.save(_fileDescriptor);
        } else {
            var fileTarget:File = new File(_fileDescriptor.fileTargetPath);
            if (fileTarget.exists)
                fileTarget.deleteFile();
            Registry.remove(_fileDescriptor);
        }

        try {
            if (_loader) {
                _loader.close();
                _loader = null;
            }

            if (_fs) {
                _fs.close();
                _fs = null;
            }
        }
        catch (error:Error) {
            //trace("error: " + error.message);
        }

        Registry.close();
        System.gc();

        // Have to send an aborted messsage status to inform my parent Worker
        // it can terminate me because of a bug working with file system.
        sendStatus(AbstractDownloadFileWorker.ABORTED_STATUS);
    }

    protected function flushLastBytes():void {
        clearInterval(_intervalId);

        if (_buf.length != _fileDescriptor.bytesTotal)
            flushPartialDownloadToMemory();

        try {
            _loader.close();
        } catch (error:Error) {
            //trace("error: " + error.message);
        }
    }

    protected function sendProgressAtTick():void {
        _fileDescriptor.bytesLoaded = _offs;
        var percentLoaded:Number = Number(Number(_offs * 100 / _fileDescriptor.bytesTotal).toFixed(_fileDescriptor.progressPrecision));


        // only send progress messages every
        // progressPrecision milestone with a
        // minimum of half second of delay
        // to avoid flooding the message channel.
        if (percentLoaded != _oldPercentLoaded) {
            _oldPercentLoaded = percentLoaded;
            _fileDescriptor.bytesLoaded = _offs;

            //trace("progress: " + percentLoaded + " : " + _offs + " / " + _fileDescriptor.bytesTotal);

            sendProgress(_fileDescriptor);
        }
    }

    protected function flushPartialDownloadToMemory():void {

        try {
            var len:uint = _loader.bytesAvailable;

            if (len) {
                _loader.readBytes(_buf, _offs - _flushedBytes, len);
                _offs += len;

                if (_paused) {
                    _loader.close();
                    clearInterval(_intervalId);
                }
            }
        } catch (error:Error) {
            //trace("error: " + error.message);
        }
    }

    protected function writeFileTarget():void {
        var fileTarget:File = new File(_fileDescriptor.fileTargetPath);

        fileTarget.downloaded = true;
        fileTarget.preventBackup = true;

        _fs = new FileStream();
        _fs.addEventListener(IOErrorEvent.IO_ERROR, handleDownloadError, false, 0, true);
        _fs.open(fileTarget, FileMode.APPEND);
        _fs.writeBytes(_buf, 0, _buf.length);
    }
}
}