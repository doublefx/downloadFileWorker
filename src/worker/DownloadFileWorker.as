package worker
{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.system.System;
	import flash.utils.ByteArray;
	
	import worker.util.AbstractDownloadFileWorker;
	import worker.util.IDownloadFileWorker;
	import worker.vo.DownloadFileDescriptor;
	
	public class DownloadFileWorker extends AbstractDownloadFileWorker {
				
		protected var _fileDescriptor:DownloadFileDescriptor;
		protected var _useCache:Boolean = true;		
		protected var _loader:URLLoader = null;		
		protected var _oldPercentLoaded:Number = 0;
		
		private static const CLASSNAME:String = "DownloadFileWorker";
		
		public static function create(downloadFileDescriptor: DownloadFileDescriptor, onProgress:Function = null, onError:Function = null, onCompleted:Function = null):IDownloadFileWorker {			
			return AbstractDownloadFileWorker.create(CLASSNAME, downloadFileDescriptor, onProgress, onError, onCompleted);
		}
						
		override protected function handleCommandMessage(event:Event):void
		{
			super.handleCommandMessage(event);
			
			try {
				var message:* = getMessage();
				
				
				if (!_loader && message is Array && message.length == 2 && message[0] == DOWNLOAD_MESSAGE && message[1] is DownloadFileDescriptor) {
					_fileDescriptor = message[1] as DownloadFileDescriptor;
				} else {
					
					switch(message)
					{
						case USE_CACHE_MESSAGE:
						{
							_useCache = getMessage();
							break;
						}
						case PAUSE_MESSAGE:
						{
							var pause:Boolean = true;
							while (pause) {					
								var msg:* = getMessage(true);
								if (msg == RESUME_MESSAGE || msg == ABORD_MESSAGE) {
									pause = false;
									if (msg == RESUME_MESSAGE)
										return;
								}
							}
						}
						case ABORD_MESSAGE:
						{
							destroy();
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
			
			with (_fileDescriptor) {
				if (fileTarget.exists) {
					if (!_useCache) {
						fileTarget.deleteFileAsync();
					} else {
						bytesLoaded = bytesTotal = fileTarget.size;
						sendProgress(_fileDescriptor);
						sendResult(_fileDescriptor);
						return;
					}	
				}
				
				if (fileUrl.search("http") == 0) {
					download(fileUrl);
				} else if (url.search("file://") == 0) {
					download(fileUrl);
				} else {				
					source = new File(fileUrl);
					
					try {
						source.copyTo(fileTarget, true);
					} catch (error:Error) {
						sendError(error);
					}
				}
			}
		}
		
		protected function download(url:String):void {
			var l:URLStream = new URLStream();
			_loader = new URLLoader();
			var req:URLRequest = new URLRequest(url + "?" + new Date().getTime());
			//Wait for 5 minutes before aborting download attempt.  Adobe download sites as well as some Apache mirrors are extremely slow.
			req.idleTimeout = 300000;
			
			with (_loader) {
				dataFormat = URLLoaderDataFormat.BINARY;
				addEventListener(Event.COMPLETE, handleDownloadComplete, false, 0, true);
				
				addEventListener(ErrorEvent.ERROR, handleDownloadError, false, 0, true);
				addEventListener(IOErrorEvent.IO_ERROR, handleDownloadError, false, 0, true);
				addEventListener(ProgressEvent.PROGRESS, handleDownloadProgress, false, 0, true);
				
				load(req);
			}
		}
		
		protected function handleDownloadProgress(event:ProgressEvent):void {
			var bytesTotal:Number = event.bytesTotal;
			var bytesLoaded:Number = event.bytesLoaded;
			var percentLoaded:Number = Number(Number(bytesLoaded * 100 / bytesTotal).toFixed(_fileDescriptor.progressPrecision));
			
			// only send progress messages every user defined milestone
			// to avoid flooding the message channel
			if (percentLoaded !=  _oldPercentLoaded)
			{
				_oldPercentLoaded = percentLoaded;
				
				_fileDescriptor.bytesLoaded = bytesLoaded;
				_fileDescriptor.bytesTotal = bytesTotal;
				sendProgress(_fileDescriptor);
			}
		}
		
		protected function handleDownloadError(event:ErrorEvent):void {
			sendError(new Error(event.text, event.errorID));
		}
		
		protected function handleDownloadComplete(event:Event):void {			
			writeFile(event.target.data);						
			var fileTarget:File = new File(_fileDescriptor.fileTargetPath);
			
			sendResult(_fileDescriptor);
		}
		
		protected function writeFile(data:ByteArray):void {
			var file:File = new File(_fileDescriptor.fileTargetPath);		
			var fs:FileStream = new FileStream();		
			
			with (fs) {
				open(file, FileMode.WRITE);
				writeBytes(data);
				close();
			}			
			
			file.downloaded = true;
			file.preventBackup = true;
		}
		
		protected function destroy():void {
			
			if (_loader) {
				with (_loader) {
					
					close();
					
					removeEventListener(ErrorEvent.ERROR, handleDownloadError);
					removeEventListener(IOErrorEvent.IO_ERROR, handleDownloadError);
					removeEventListener(ProgressEvent.PROGRESS, handleDownloadProgress);
					
					if (data) {
						ByteArray(data).clear();
					}
				}
			}
			_loader = null;
			
			System.gc();
		}
	}
}