package infrastructure.worker.api.downloadFileWorker {
import domain.vo.DownloadFileDescriptor;

import flash.desktop.NativeApplication;
import flash.events.Event;
import flash.system.MessageChannel;
import flash.system.MessageChannelState;
import flash.system.Worker;

import infrastructure.worker.api.AbstractWorker;
import infrastructure.worker.util.RegisterUtil;
import infrastructure.worker.util.db.Registry;

public class AbstractDownloadFileWorker extends AbstractWorker {

    public static const DOWNLOAD_MESSAGE:String = "DOWNLOAD_MESSAGE";
    public static const USE_CACHE_MESSAGE:String = "USE_CACHE_MESSAGE";
    public static const PAUSE_MESSAGE:String = "PAUSE_MESSAGE";
    public static const RESUME_MESSAGE:String = "RESUME_MESSAGE";
    public static const ABORT_MESSAGE:String = "ABORT_MESSAGE";

    public static const RESUMABLE_STATUS:String = "RESUMABLE_STATUS";

    protected var hasMessage:Boolean;

    private var _commandChannel:MessageChannel;
    private var _statusChannel:MessageChannel;
    private var _progressChannel:MessageChannel;
    private var _errorChannel:MessageChannel;
    private var _resultChannel:MessageChannel;

    function AbstractDownloadFileWorker(protectedConstructor:AbstractDownloadFileWorker):void {
        super(protectedConstructor);
    }

    override protected function initialize():void {

        RegisterUtil.registerClassAliases();

        workerName = Worker.current.getSharedProperty("workerName");
        var dbPath:String = Worker.current.getSharedProperty("dbPath");

        Registry.initialize(dbPath, NativeApplication.nativeApplication.applicationID + "[" + workerName + "]");

        // Get the MessageChannel objects to use for communicating between workers
        // These are for sending messages to the parent infrastructure.worker
        _progressChannel = Worker.current.getSharedProperty(workerName + "_progressChannel") as MessageChannel;
        _errorChannel = Worker.current.getSharedProperty(workerName + "_errorChannel") as MessageChannel;
        _resultChannel = Worker.current.getSharedProperty(workerName + "_resultChannel") as MessageChannel;
        _statusChannel = Worker.current.getSharedProperty(workerName + "_statusChannel") as MessageChannel;
        // This one is for receiving messages from the parent infrastructure.worker
        _commandChannel = Worker.current.getSharedProperty(workerName + "_commandChannel") as MessageChannel;
        _commandChannel.addEventListener(Event.CHANNEL_MESSAGE, handleCommandMessage);
    }

    protected function handleCommandMessage(event:Event):void {
        if (_commandChannel.state != MessageChannelState.OPEN) {
            trace("Error: MessageChannel was " + _commandChannel.state + " while trying to execute command.");
            return;
        }

        hasMessage = _commandChannel.messageAvailable;
    }

    protected function getMessage(blockUntilReceived:Boolean = false):* {
        return _commandChannel.receive(blockUntilReceived);
    }

    protected function sendStatus(status:String, queueLimit:int = -1):void {
        if (_statusChannel.state != MessageChannelState.OPEN) {
            trace("Error: MessageChannel was " + _statusChannel.state + " while trying to sendStatus " + status);
            return;
        }

        _statusChannel.send(status);
    }

    protected function sendProgress(fileDescriptor:DownloadFileDescriptor, queueLimit:int = -1):void {
        if (_progressChannel.state != MessageChannelState.OPEN) {
            trace("Error: MessageChannel was " + _progressChannel.state + " while trying to sendProgress " + fileDescriptor);
            return;
        }

        _progressChannel.send(fileDescriptor, queueLimit);
    }

    protected function sendError(error:Error, queueLimit:int = -1):void {
        if (_errorChannel.state != MessageChannelState.OPEN) {
            trace("Error: MessageChannel was " + _errorChannel.state + " while trying to sendError " + error);
            return;
        }

        _errorChannel.send(error, queueLimit);
    }

    protected function sendResult(fileDescriptor:DownloadFileDescriptor, queueLimit:int = -1):void {
        if (_resultChannel.state != MessageChannelState.OPEN) {
            trace("Error: MessageChannel was " + _resultChannel.state + " while trying to sendResult " + fileDescriptor);
            return;
        }

        _resultChannel.send(fileDescriptor, queueLimit);
    }
}
}
