package infrastructure.worker.api.downloadFileWorker {
import domain.vo.DownloadFileDescriptor;

import flash.events.IEventDispatcher;

[Bindable]
public interface IDownloadFileWorker extends IEventDispatcher {
    function start():void;

    function terminate():Boolean;

    function pause():void;

    function resume():void;

    function get useCache():Boolean;

    function set useCache(v:Boolean):void;

    function get isRunning():Boolean;

    function get isResumable():Boolean;

    function get isPaused():Boolean;

    function get fileDescriptor():DownloadFileDescriptor;

    function get workerName():String;
}
}