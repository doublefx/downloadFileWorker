package worker.util {
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.ProgressEvent;

[Bindable]
public interface IDownloadFileWorkerUIBinder {
    function get downloader():IDownloadFileWorker;

    function set downloader(v:IDownloadFileWorker):void;

    function onProgress(event:ProgressEvent):void;

    function onError(event:ErrorEvent):void;

    function onCompleted(event:Event):void;
}
}