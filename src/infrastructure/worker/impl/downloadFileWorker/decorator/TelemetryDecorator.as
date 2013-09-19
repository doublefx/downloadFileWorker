/**
 * User: Frédéric THOMAS Date: 16/09/13 Time: 20:23
 */
package infrastructure.worker.impl.downloadFileWorker.decorator {
import domain.vo.DownloadFileDescriptor;

import flash.events.Event;
import flash.events.ProgressEvent;

import infrastructure.worker.api.downloadFileWorker.IDownloadFileWorker;
import infrastructure.worker.api.downloadFileWorker.IDownloadFileWorkerTelemetry;
import infrastructure.worker.impl.downloadFileWorker.util.db.Registry;

[Bindable]
public class TelemetryDecorator implements IDownloadFileWorker, IDownloadFileWorkerTelemetry {
    private var _decorated:IDownloadFileWorker;

    private var _startTime:Date;
    private var _endTime:Date;
    private var _totalTime:Number = 0;
    private var _totalEffectiveTime:Number = 0;
    private var _estimatedRemainingTime:Number = 0;
    private var _numberOfBytesPerSecondAverage:Number = 0;
    private var _midStartTime:Date;
    private var _midMilliseconds:Number = 0;
    private var _alreadyFlushedBytes:Number = 0;

    public function TelemetryDecorator(decorated:IDownloadFileWorker) {
        _decorated = decorated;

        if (_decorated == null)
            throw new ArgumentError("The decorated IDownloadFileWorker must not be null");
    }

    public function get startTime():Date {
        return _startTime;
    }

    public function set startTime(v:Date):void {
        _startTime = v;
    }

    public function get endTime():Date {
        return _endTime;
    }

    public function set endTime(v:Date):void {
        _endTime = v;
    }

    public function get totalTime():Number {
        return _totalTime;
    }

    public function set totalTime(v:Number):void {
        _totalTime = v;
    }

    public function get totalEffectiveTime():Number {
        return _totalEffectiveTime;
    }

    public function set totalEffectiveTime(v:Number):void {
        _totalEffectiveTime = v;
    }

    public function get estimatedRemainingTime():Number {
        return _estimatedRemainingTime;
    }

    public function set estimatedRemainingTime(v:Number):void {
        _estimatedRemainingTime = v;
    }

    public function get numberOfBytesPerSecondAverage():Number {
        return _numberOfBytesPerSecondAverage;
    }

    public function set numberOfBytesPerSecondAverage(v:Number):void {
        _numberOfBytesPerSecondAverage = v;
    }

    public function start():void {
        startTime = new Date();
        addEventHandlers();

        var fd:DownloadFileDescriptor = new DownloadFileDescriptor(fileDescriptor.fileUrl, fileDescriptor.fileTargetPath);
        Registry.load(fd);
        _alreadyFlushedBytes = fd.bytesLoaded;


        _decorated.start();
    }

    public function terminate():Boolean {
        endTime = new Date();
        removeEventHandlers();

        return _decorated.terminate();
    }

    public function pause():void {
        _midStartTime = new Date();
        removeEventHandlers();

        _decorated.pause();
    }

    public function resume():void {
        _midMilliseconds += new Date().getTime() - _midStartTime.getTime();
        addEventHandlers();

        _decorated.resume();
    }

    public function get useCache():Boolean {
        return _decorated.useCache;
    }

    public function set useCache(v:Boolean):void {
        _decorated.useCache = v;
    }

    public function get isRunning():Boolean {
        return _decorated.isRunning;
    }

    public function get isResumable():Boolean {
        return _decorated.isResumable;
    }

    public function get isPaused():Boolean {
        return _decorated.isPaused;
    }

    public function get fileDescriptor():DownloadFileDescriptor {
        return _decorated.fileDescriptor;
    }

    public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void {
        _decorated.addEventListener(type, listener, useCapture, priority, useWeakReference);
    }

    public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void {
        _decorated.removeEventListener(type, listener, useCapture);
    }

    public function dispatchEvent(event:Event):Boolean {
        return _decorated.dispatchEvent(event);
    }

    public function hasEventListener(type:String):Boolean {
        return _decorated.hasEventListener(type);
    }

    public function willTrigger(type:String):Boolean {
        return _decorated.willTrigger(type);
    }

    private function addEventHandlers():void {
        _decorated.addEventListener(ProgressEvent.PROGRESS, decorated_progressHandler);
        _decorated.addEventListener(Event.COMPLETE, decorated_completeHandler);
    }

    private function removeEventHandlers():void {
        _decorated.removeEventListener(ProgressEvent.PROGRESS, decorated_progressHandler);
        _decorated.removeEventListener(Event.COMPLETE, decorated_completeHandler);
    }

    private function decorated_progressHandler(event:ProgressEvent):void {
        doTelemetry();
    }

    private function decorated_completeHandler(event:Event):void {
        doTelemetry();
    }

    private function doTelemetry():void {
        var now:Date = _endTime ? _endTime : new Date();

        totalTime = now.getTime() - _startTime.getTime();
        totalEffectiveTime = _totalTime - _midMilliseconds;
        numberOfBytesPerSecondAverage = (fileDescriptor.bytesLoaded - _alreadyFlushedBytes) / _totalEffectiveTime * 1000;
        estimatedRemainingTime = (fileDescriptor.bytesTotal - fileDescriptor.bytesLoaded + _alreadyFlushedBytes) / _numberOfBytesPerSecondAverage * 1000;
    }
}
}