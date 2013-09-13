package worker.util {
import flash.events.Event;
import flash.system.MessageChannel;
import flash.system.Worker;

import worker.vo.DownloadFileDescriptor;

public class AbstractDownloadFileWorker extends AbstractWorker {
    public static const DOWNLOAD_MESSAGE:String = "DOWNLOAD_MESSAGE";
    public static const USE_CACHE_MESSAGE:String = "USE_CACHE_MESSAGE";
    public static const PAUSE_MESSAGE:String = "PAUSE_MESSAGE";
    public static const RESUME_MESSAGE:String = "RESUME_MESSAGE";
    public static const ABORT_MESSAGE:String = "ABORT_MESSAGE";

    public static const RESUMABLE_STATUS:String = "RESUMABLE_STATUS";

    private var _commandChannel:MessageChannel;
    private var _statusChannel:MessageChannel;
    private var _progressChannel:MessageChannel;
    private var _errorChannel:MessageChannel;
    private var _resultChannel:MessageChannel;

    override protected function initialize():void {

        workerName = Worker.current.getSharedProperty("workerName");

        // Get the MessageChannel objects to use for communicating between workers
        // These are for sending messages to the parent worker
        _progressChannel = Worker.current.getSharedProperty(workerName + "_progressChannel") as MessageChannel;
        _errorChannel = Worker.current.getSharedProperty(workerName + "_errorChannel") as MessageChannel;
        _resultChannel = Worker.current.getSharedProperty(workerName + "_resultChannel") as MessageChannel;
        _statusChannel = Worker.current.getSharedProperty(workerName + "_statusChannel") as MessageChannel;
        // This one is for receiving messages from the parent worker
        _commandChannel = Worker.current.getSharedProperty(workerName + "_commandChannel") as MessageChannel;
        _commandChannel.addEventListener(Event.CHANNEL_MESSAGE, handleCommandMessage);
    }

    protected function handleCommandMessage(event:Event):void {
        if (!_commandChannel.messageAvailable)
            return;
    }

    protected function getMessage(waitFor:Boolean = false):* {
        return _commandChannel.receive(waitFor);
    }

    protected function sendStatus(status:String, queueLimit:int = -1):* {
        return _statusChannel.send(status);
    }

    protected function sendProgress(fileDescriptor:DownloadFileDescriptor, queueLimit:int = -1):void {
        _progressChannel.send(fileDescriptor, queueLimit);
    }

    protected function sendError(error:Error, queueLimit:int = -1):void {
        _errorChannel.send(error, queueLimit);
    }

    protected function sendResult(fileDescriptor:DownloadFileDescriptor, queueLimit:int = -1):void {
        _resultChannel.send(fileDescriptor, queueLimit);
    }
}
}

