package worker.util {
import flash.events.IEventDispatcher;

import worker.vo.DownloadFileDescriptor;

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
}
}