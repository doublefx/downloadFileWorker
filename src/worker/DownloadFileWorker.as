package worker {
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

import worker.util.AbstractDownloadFileWorker;
import worker.vo.DownloadFileDescriptor;

public class DownloadFileWorker extends AbstractDownloadFileWorker {

    protected var _fileDescriptor:DownloadFileDescriptor;
    protected var _useCache:Boolean = true;
    protected var _loader:URLStream = null;
    protected var _req:URLRequest = null;
    protected var _oldPercentLoaded:Number = 0;

    private var _fs:FileStream;
    private var _buf:ByteArray;
    private var _offs:Number;
    private var _paused:Boolean;
    private var _intervalId:uint;

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
	                            if (msg == RESUME_MESSAGE || msg == ABORT_MESSAGE) {
	                                if (msg == RESUME_MESSAGE) {
	                                    resume();
	                                    return;
	                                }
	                            }
	                        }
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
	            sendError(error);
	        }
    }

    protected function copyOrDownload():void {
        var source:File;
        var fileTarget:File = new File(_fileDescriptor.fileTargetPath);

        if (fileTarget.exists) {
            if (!_useCache) {
                fileTarget.deleteFile();
            } else {
                _fileDescriptor.bytesLoaded = _fileDescriptor.bytesTotal = fileTarget.size;
                sendProgress(_fileDescriptor);
                sendResult(_fileDescriptor);
                return;
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
        //Wait for 5 minutes before aborting download attempt.  Adobe download sites as well as some Apache mirrors are extremely slow.
        _req.idleTimeout = 300000;

        _buf = new ByteArray();
        _offs = 0;
        _paused = false;

        _loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onDownloadResponseStatus);

        _loader.addEventListener(ErrorEvent.ERROR, handleDownloadError, false, 0, true);
        _loader.addEventListener(IOErrorEvent.IO_ERROR, handleDownloadError, false, 0, true);
        _loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleDownloadError, false, 0, true);

        _loader.addEventListener(ProgressEvent.PROGRESS, handleDownloadProgress, false, 0, true);
        _loader.addEventListener(Event.COMPLETE, handleDownloadComplete, false, 0, true);

        _loader.load(_req);

        _intervalId = setInterval(partialLoad, 500);
    }

    protected function partialLoad():void {

        try {
            var len:uint = _loader.bytesAvailable;

            if (len) {
                _loader.readBytes(_buf, _offs, len);
                _offs += len;

                if (_paused) {
                    _loader.close();
                    clearInterval(_intervalId);
                }
            }
        } catch (error:Error) {
        }
    }

    protected function pause():void {
        _paused = true;
    }

    protected function resume():void {
        _req.requestHeaders = [new URLRequestHeader("Range", "bytes=" + _offs + "-")];
        _loader.load(_req);
        _paused = false;
        _intervalId = setInterval(partialLoad, 500);
    }

    protected function onDownloadResponseStatus(event:HTTPStatusEvent):void {
        addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onDownloadResponseStatus);
        var header:URLRequestHeader;

        if (event.status == 200)
            for each (header in event.responseHeaders) {
                if (header.name == "Accept-Ranges" && header.value == "bytes") {
                    sendStatus(AbstractDownloadFileWorker.RESUMABLE_STATUS);
                    break
                }
            }
    }

    protected function handleDownloadProgress(event:ProgressEvent):void {
        if (isNaN(_fileDescriptor.bytesTotal)) {
            _fileDescriptor.bytesTotal = event.bytesTotal;
        }
        var percentLoaded:Number = Number(Number(_offs * 100 / _fileDescriptor.bytesTotal).toFixed(_fileDescriptor.progressPrecision));


        // only send progress messages every user defined milestone
        // with a minimum of half second of delay
        // to avoid flooding the message channel
        if (percentLoaded != _oldPercentLoaded) {
            _oldPercentLoaded = percentLoaded;
            _fileDescriptor.bytesLoaded = _offs;

            sendProgress(_fileDescriptor);
        }
    }

    protected function handleDownloadError(event:ErrorEvent):void {
        sendError(new Error(event.text, event.errorID));
    }

    protected function handleDownloadComplete(event:Event):void {
        flushLastBytes();
        writeFileTarget();

        sendResult(_fileDescriptor);
    }

    protected function flushLastBytes():void {
        clearInterval(_intervalId);

        while (_buf.length != _fileDescriptor.bytesTotal)
            partialLoad();

        _loader.close();

        _fileDescriptor.bytesLoaded = _offs;
        sendProgress(_fileDescriptor);
    }

    protected function writeFileTarget():void {
        var fileTarget:File = new File(_fileDescriptor.fileTargetPath);

        fileTarget.downloaded = true;
        fileTarget.preventBackup = true;

        _fs = new FileStream();
        _fs.addEventListener(IOErrorEvent.IO_ERROR, handleDownloadError, false, 0, true);
        _fs.open(fileTarget, FileMode.WRITE);
        _fs.writeBytes(_buf, 0, _buf.length);
    }

    protected function abort():void {

        clearInterval(_intervalId);

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
        }

        System.gc();
    }
}
}