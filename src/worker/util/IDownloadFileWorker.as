package worker.util {
import worker.vo.DownloadFileDescriptor;

[Bindable]
public interface IDownloadFileWorker {
    function start():void;

    function terminate():Boolean;

    function pause():void;

    function resume():void;

    function get useCache():Boolean;

    function set useCache(v:Boolean):void;

    function get isRunning():Boolean;

    function get isResumable():Boolean;

    function get isPaused():Boolean;

    function get isTerminated():Boolean;

    function get fileDescriptor():DownloadFileDescriptor;
}
}