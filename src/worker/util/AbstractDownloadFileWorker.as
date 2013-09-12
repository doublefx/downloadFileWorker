package worker.util
{
	import flash.events.Event;
	import flash.net.registerClassAlias;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	
	import mx.utils.NameUtil;
	
	import avmplus.getQualifiedClassName;
	
	import worker.vo.DownloadFileDescriptor;

	public class AbstractDownloadFileWorker extends AbstractWorker
	{		
		public static const DOWNLOAD_MESSAGE:String = "DOWNLOAD_MESSAGE";
		public static const USE_CACHE_MESSAGE:String = "USE_CACHE_MESSAGE";
		public static const PAUSE_MESSAGE:String = "PAUSE_MESSAGE";
		public static const RESUME_MESSAGE:String = "RESUME_MESSAGE";
		public static const ABORD_MESSAGE:String = "ABORD_MESSAGE";
		
		private var _commandChannel:MessageChannel;
		private var _progressChannel:MessageChannel;
		private var _errorChannel:MessageChannel;
		private var _resultChannel:MessageChannel;
		
		private var className:String;
		
		public static function create(wrappedClassName:String, downloadFileDescriptor: DownloadFileDescriptor, onProgress:Function = null, onError:Function = null, onCompleted:Function = null):DownloadFileWrapper {
			return new DownloadFileWrapper(wrappedClassName, downloadFileDescriptor, onProgress, onError, onProgress);
		}
		
		public function AbstractDownloadFileWorker()
		{
			super();
		}
		
		override protected function initialize():void {	
			className = NameUtil.getUnqualifiedClassName(this);
			trace(className + ".initialize");
			
			DownloadFileWrapper.registerClassAliases();
			
			// Get the MessageChannel objects to use for communicating between workers
			// These are for sending messages to the parent worker
			_progressChannel = Worker.current.getSharedProperty("progressChannel" + className) as MessageChannel;
			_errorChannel = Worker.current.getSharedProperty("errorChannel" + className) as MessageChannel;
			_resultChannel = Worker.current.getSharedProperty("resultChannel" + className) as MessageChannel;	
			// This one is for receiving messages from the parent worker
			_commandChannel = Worker.current.getSharedProperty("commandChannel" + className) as MessageChannel;
			_commandChannel.addEventListener(Event.CHANNEL_MESSAGE, handleCommandMessage);	
		}
		
		protected function handleCommandMessage(event:Event):void
		{
			trace(className + ".handleCommandMessage");
			
			if (!_commandChannel.messageAvailable)
				return;
		}
		
		protected function getMessage(waitFor:Boolean = false):* {
			return _commandChannel.receive(waitFor);
		}
		
		protected function sendProgress(fileDescriptor:DownloadFileDescriptor):void {
			_progressChannel.send(fileDescriptor);
		}
		
		protected function sendError(error:Error):void {
			_errorChannel.send(error);
		}
		
		protected function sendResult(fileDescriptor:DownloadFileDescriptor):void {
			_resultChannel.send(fileDescriptor);
		}
	}
}


import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.ProgressEvent;
import flash.net.registerClassAlias;
import flash.system.MessageChannel;
import flash.system.Worker;
import flash.system.WorkerDomain;
import flash.system.WorkerState;

import worker.util.AbstractDownloadFileWorker;
import worker.util.IDownloadFileWorker;
import worker.vo.DownloadFileDescriptor;

[Bindable]
internal class DownloadFileWrapper extends EventDispatcher implements IDownloadFileWorker {
		
	private var _worker:Worker;
	private var _commandChannel:MessageChannel;
	private var _progressChannel:MessageChannel;
	private var _errorChannel:MessageChannel;
	private var _resultChannel:MessageChannel;	
	
	private var _onProgress:Function;
	private var _onError:Function;
	private var _onCompleted:Function;
	
	private var _useCache:Boolean = true;
	
	private var _downloadFileDescriptor: DownloadFileDescriptor;
	
	private var _isPaused:Boolean;
	private var _isResumed:Boolean;
	private var _isRunning:Boolean;
	private var _isTerminated:Boolean = true;
	
	internal static function registerClassAliases():void {
		// Register our classes we are serialzing
		registerClassAlias("Error", Error);
		registerClassAlias("ReferenceError", ReferenceError);
		registerClassAlias("ArgumentError", ArgumentError);
		registerClassAlias("TypeError", TypeError);
		registerClassAlias("SecurityError", SecurityError);
		registerClassAlias("worker.vo.DownloadFileDescriptor", DownloadFileDescriptor);		
	}
	
	public function DownloadFileWrapper (wrappedClassName:String, downloadFileDescriptor: DownloadFileDescriptor, onProgress:Function = null, onError:Function = null, onCompleted:Function = null):void {
		
		_downloadFileDescriptor = downloadFileDescriptor;
		_onProgress = onProgress;
		_onError = onError;
		_onCompleted = onCompleted;
		
		registerClassAliases();		
		createWorker(wrappedClassName);
	}	
	
	private function onStateChangedWrapper(event:Event):void {		
		
		switch(_worker.state)
		{
			case WorkerState.RUNNING:
			{
				_commandChannel.send([AbstractDownloadFileWorker.DOWNLOAD_MESSAGE, _downloadFileDescriptor]);
				isRunning = true;
				isTerminated = false;
				addEventListeners();	
				break;
			}
				
			case WorkerState.TERMINATED:
			{
				isRunning = false;
				isTerminated = true;
				removeListeners();
				break;
			}
		}
	}
		
	private function onProgressWrapper(event:Event):void {	
		_downloadFileDescriptor = _progressChannel.receive();
		var destEvent:ProgressEvent = new ProgressEvent(ProgressEvent.PROGRESS, false, false, _downloadFileDescriptor.bytesLoaded, _downloadFileDescriptor.bytesTotal);
		dispatchEvent(destEvent);
	}
	
	private function onErrorWrapper(event:Event):void {	
		var error:Error = _errorChannel.receive();
		var destEvent:ErrorEvent = new ErrorEvent(ErrorEvent.ERROR, false, false, error.message, error.errorID);
		dispatchEvent(destEvent);
	}
	
	private function onFinishedWrapper(event:Event):void {	
		_downloadFileDescriptor = _resultChannel.receive();
		var destEvent:Event = new Event(Event.COMPLETE, false, false);
		dispatchEvent(destEvent);
	}
	
	public function start():void {
		if (_worker.state == WorkerState.NEW)
			_worker.start();
	}
	
	public function terminate():Boolean {
		var b:Boolean = true;
		
		if (_worker.state != WorkerState.TERMINATED) {
			_commandChannel.send(AbstractDownloadFileWorker.ABORD_MESSAGE);
			b = _worker.terminate();
		}
		return b;
	}
	
	public function pause():void {
		if (_isRunning) {
			_commandChannel.send(AbstractDownloadFileWorker.PAUSE_MESSAGE);
			isPaused = true;
		}
	}
	
	public function resume():void {
		if (isPaused) {
			_commandChannel.send(AbstractDownloadFileWorker.RESUME_MESSAGE);
			isPaused = false;
		}
	}
	
	public function get useCache():Boolean
	{
		return _useCache;
	}
	
	public function set useCache(v:Boolean):void
	{
		_commandChannel.send(AbstractDownloadFileWorker.USE_CACHE_MESSAGE);
		_commandChannel.send(v);
		_useCache = v;
	}
	
	public function get isTerminated():Boolean
	{
		return _isTerminated;
	}
	
	public function set isTerminated(v:Boolean):void {
		_isTerminated = v;
	}
	
	public function get isPaused():Boolean
	{
		return !_isTerminated && _isRunning && _isPaused;
	}
	
	public function set isPaused(v:Boolean):void {
		_isPaused = v;
	}
	
	public function get isRunning():Boolean
	{
		return _isRunning;
	}
	
	public function set isRunning(v:Boolean):void {
		_isRunning = v;
	}
	
	
	public function get fileDescriptor():DownloadFileDescriptor {
		return _downloadFileDescriptor;
	}	
	
	private function createWorker(wrappedClass:String):void {
				
		// Create the background worker
		_worker = WorkerDomain.current.createWorker(WorkerManager.downloadFileWorker, true);
		
		// Set up the MessageChannels for communication between workers
		_commandChannel = Worker.current.createMessageChannel(_worker);
		_worker.setSharedProperty("commandChannel" + wrappedClass, _commandChannel);
		
		// Set up listeners
		_worker.addEventListener(Event.WORKER_STATE, onStateChangedWrapper);
		
		_progressChannel = _worker.createMessageChannel(Worker.current);
		_progressChannel.addEventListener(Event.CHANNEL_MESSAGE, onProgressWrapper)
		_worker.setSharedProperty("progressChannel" + wrappedClass, _progressChannel);
		
		_errorChannel = _worker.createMessageChannel(Worker.current);
		_errorChannel.addEventListener(Event.CHANNEL_MESSAGE, onErrorWrapper)
		_worker.setSharedProperty("errorChannel" + wrappedClass, _errorChannel);
		
		_resultChannel = _worker.createMessageChannel(Worker.current);
		_resultChannel.addEventListener(Event.CHANNEL_MESSAGE, onFinishedWrapper);
		_worker.setSharedProperty("resultChannel" + wrappedClass, _resultChannel);
	}
	
	private function addEventListeners():void {
				
		if (_onProgress != null)
			addEventListener(ProgressEvent.PROGRESS, _onProgress);
		
		if (_onError != null)
			addEventListener(ErrorEvent.ERROR, _onError);
		
		if (_onCompleted != null)
			addEventListener(Event.COMPLETE, _onCompleted);
	}
	
	private function removeListeners():void {
		
		_worker.removeEventListener(Event.WORKER_STATE, onStateChangedWrapper);
		_progressChannel.removeEventListener(Event.CHANNEL_MESSAGE, onProgressWrapper)
		_errorChannel.removeEventListener(Event.CHANNEL_MESSAGE, onErrorWrapper)
		_resultChannel.removeEventListener(Event.CHANNEL_MESSAGE, onFinishedWrapper);
		
		if (_onProgress != null)
			removeEventListener(ProgressEvent.PROGRESS, _onProgress);
		
		if (_onError != null)
			removeEventListener(ErrorEvent.ERROR, _onError);
		
		if (_onCompleted != null)
			removeEventListener(Event.COMPLETE, _onCompleted);
		
		_onProgress = 
			_onError = 
			_onCompleted = null;
	}
	
}
